"""Print the partner-app order-flow state for a phone-registered user. Used to figure out why a
supplier's Buyurtmalar tab is empty: wrong role? no listings? no orders against their listings?

Usage:
  python manage.py diagnose_partner --phone +998993102505

Run on Railway via the dashboard's service Shell — `railway run` can't reach postgres.railway.internal
from a laptop because that hostname only resolves inside the Railway private network.
"""
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Dump a partner user's role/profile/listings/orders so we can see why their inbox is empty."

    def add_arguments(self, parser):
        parser.add_argument("--phone", required=True,
                            help="E.164 phone number, e.g. +998993102505")

    def handle(self, *args, **opts):
        from apps.accounts.models import User
        from apps.listings.models import Listing
        from apps.orders.models import Order

        try:
            u = User.objects.get(phone=opts["phone"])
        except User.DoesNotExist:
            raise CommandError(f"No user with phone={opts['phone']}. Sign up first or check the number.")

        sp = getattr(u, "supplier_profile", None)
        self.stdout.write(self.style.SUCCESS(
            f"User #{u.id} email={u.email} role={u.role} "
            f"supplier_profile={'yes is_verified=' + str(sp.is_verified) if sp else 'NO'}"))

        listings = Listing.objects.filter(supplier=u).only("id", "name_uz", "status")
        self.stdout.write(self.style.SUCCESS(f"\n--- My listings (supplier=#{u.id})  count={listings.count()} ---"))
        for l in listings:
            self.stdout.write(f"  #{l.id}  {l.name_uz}  status={l.status}")
        if not listings:
            self.stdout.write(self.style.WARNING(
                "  (none — create a listing in the partner app first)"))

        my_orders = (Order.objects
                     .filter(listing__supplier=u)
                     .select_related("listing", "buyer")
                     .order_by("-id"))
        self.stdout.write(self.style.SUCCESS(
            f"\n--- Orders on MY listings (what /partner/inbox/ sees)  count={my_orders.count()} ---"))
        for o in my_orders:
            self.stdout.write(
                f"  #{o.id}  listing=#{o.listing_id} ({o.listing.name_uz})  "
                f"status={o.status}  buyer={o.buyer.email}")
        if not my_orders:
            self.stdout.write(self.style.WARNING(
                "  (none — either no buyer ordered yours, OR they ordered a different supplier's listing)"))

        recent = (Order.objects
                  .select_related("listing", "listing__supplier")
                  .order_by("-id")[:10])
        self.stdout.write(self.style.SUCCESS(
            "\n--- 10 most recent orders ON THE PLATFORM (any supplier) ---"))
        for o in recent:
            mine = " ← MINE" if o.listing.supplier_id == u.id else ""
            self.stdout.write(
                f"  #{o.id}  listing=#{o.listing_id} supplier=#{o.listing.supplier_id} "
                f"({o.listing.supplier.email})  status={o.status}{mine}")
