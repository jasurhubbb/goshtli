"""seed_demo — populate the database with demo accounts + listings + a sample order, for app testing.

Idempotent: uses get_or_create on every entity, so re-running on a populated DB is a no-op (no duplicates).
Safe to wire into entrypoint.sh — runs on every container boot but only inserts on first run.

What it creates:
  3 suppliers (2 verified, 1 unverified — so we can test the verification gate from the app)
  3 buyers
  4 listings spanning meat types and regions, owned by the 2 verified suppliers
  1 sample PENDING order (buyer1 → supplier1's first listing) so the dashboard isn't empty

All passwords are 'Test1234!' for ease of testing. Change before going to real users.
"""
from datetime import date, timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.db import transaction

from apps.accounts.models import User
from apps.buyers.models import BuyerProfile
from apps.listings.models import Listing
from apps.orders.models import Order
from apps.suppliers.models import SupplierProfile


class Command(BaseCommand):
    help = "Populate database with demo suppliers, buyers, listings, and a sample order."

    PASSWORD = "Test1234!"

    @transaction.atomic
    def handle(self, *args, **options):
        suppliers = [
            self._user("supplier1@test.com", "Beg Supplier", User.Role.SUPPLIER, verified=True,
                       business="Beg Meat Co.", region="Tashkent", address="Yunusabad 12"),
            self._user("supplier2@test.com", "Olim Supplier", User.Role.SUPPLIER, verified=True,
                       business="Olim Halol Foods", region="Samarkand", address="Registon st 5"),
            self._user("supplier3@test.com", "Yangi Supplier", User.Role.SUPPLIER, verified=False,
                       business="New Supplier (pending verification)", region="Bukhara", address=""),
        ]
        buyers = [
            self._user("buyer1@test.com", "Olim Buyer", User.Role.BUYER, business="Restoran Aziz", region="Tashkent"),
            self._user("buyer2@test.com", "Bobur Buyer", User.Role.BUYER, business="Plov Center", region="Samarkand"),
            self._user("buyer3@test.com", "Dilnoza Buyer", User.Role.BUYER, business="Cafe Yulduz", region="Bukhara"),
        ]

        # Listings — only verified suppliers can have them per business rules
        s1, s2, _ = suppliers
        soon = date.today() + timedelta(days=2)
        listings = [
            self._listing(s1, "Premium Beef", Listing.MeatType.BEEF, "100.00", "50000.00", "Tashkent", soon,
                          "Grass-fed Hereford, halal slaughter, delivery same day."),
            self._listing(s1, "Local Mutton", Listing.MeatType.MUTTON, "30.00", "70000.00", "Tashkent", soon,
                          "Young lamb from Surxondaryo region."),
            self._listing(s2, "Fresh Chicken", Listing.MeatType.CHICKEN, "60.00", "25000.00", "Samarkand", soon,
                          "Free-range, antibiotic-free chickens."),
            self._listing(s2, "Goat Meat", Listing.MeatType.GOAT, "20.00", "80000.00", "Samarkand", soon, ""),
        ]

        # Sample PENDING order so the buyer + supplier dashboards aren't empty for screenshots
        b1 = buyers[0]
        first_listing = listings[0]
        Order.objects.get_or_create(buyer=b1, listing=first_listing, defaults={
            "quantity_kg": Decimal("5.00"),
            "total_price": Decimal("5.00") * first_listing.price_per_kg,
            "delivery_address": "Tashkent center, Restoran Aziz",
            "notes": "Please call before delivery",
            "status": Order.Status.PENDING})

        self.stdout.write(self.style.SUCCESS(
            f"Demo data ready — 3 suppliers, 3 buyers, {len(listings)} listings, 1 order. Password for all: {self.PASSWORD}"))

    # ------------------------------------------------------------ helpers

    def _user(self, email, full_name, role, *, verified=False, business="", region="", address=""):
        """Create or fetch a user; populate the role-specific profile if it isn't already filled."""
        user, created = User.objects.get_or_create(email=email, defaults={"full_name": full_name, "role": role})
        if created:
            user.set_password(self.PASSWORD); user.save(update_fields=("password",))
            self.stdout.write(f"  + created {role} {email}")
        else:
            self.stdout.write(f"  · exists  {role} {email}")
        # Profiles are auto-created by signals; we just fill in the editable bits if blank
        if role == User.Role.SUPPLIER:
            p = SupplierProfile.objects.get(user=user)
            if not p.business_name: p.business_name = business; p.region = region; p.address = address
            p.is_verified = verified  # always sync — tests rely on this state
            p.save()
        elif role == User.Role.BUYER:
            p = BuyerProfile.objects.get(user=user)
            if not p.business_name: p.business_name = business; p.region = region; p.address = address; p.save()
        return user

    def _listing(self, supplier, title, meat_type, qty_kg, price, location, available_from, description):
        """Create or fetch a listing scoped by (supplier, title) — idempotent re-runs."""
        listing, created = Listing.objects.get_or_create(
            supplier=supplier, title=title,
            defaults={"meat_type": meat_type, "quantity_kg": Decimal(qty_kg), "price_per_kg": Decimal(price),
                      "location": location, "available_from": available_from, "description": description,
                      "status": Listing.Status.ACTIVE})
        self.stdout.write(f"  {'+' if created else '·'} listing  {title} ({supplier.email})")
        return listing
