"""seed_demo — populate the database with demo accounts + Markets + Listings + a sample Order.

v3.1 catalog overhaul updates the demo data shape:
  • Listings now belong to a Market (created here) and a MeatCategory (seeded by migration 0004)
  • Bilingual names (uz/ru) on every listing
  • No more halal_certified / freshness_date / cold_chain / service_area — those fields are gone

Idempotent — uses get_or_create on every entity so re-running on a populated DB inserts nothing twice.
Safe to wire into entrypoint.sh.

All passwords are 'Test1234!' for ease of testing. Change before going to real users.
"""
from datetime import date, timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.db import transaction

from apps.accounts.models import User
from apps.buyers.models import BuyerProfile
from apps.listings.models import Listing, MeatCategory
from apps.markets.models import Market
from apps.orders.models import Order
from apps.suppliers.models import SupplierProfile


class Command(BaseCommand):
    help = "Populate database with demo users, markets, listings, and a sample order."

    PASSWORD = "Test1234!"

    @transaction.atomic
    def handle(self, *args, **options):
        # ---- 1. Users (suppliers operate markets; buyers place orders) ----
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

        # ---- 2. Markets — one per verified supplier ----
        s1, s2, _ = suppliers
        market1 = self._market("beg-meat-co", "Beg Meat Co.", "Бег Мясо", region="Tashkent",
                               address="Yunusabad 12, Tashkent", owner=s1)
        market2 = self._market("olim-halol", "Olim Halol", "Олим Халаль", region="Samarkand",
                               address="Registon 5, Samarkand", owner=s2)

        # ---- 3. Listings — anchored to a market + a seeded MeatCategory ----
        soon = date.today() + timedelta(days=2)
        cat_beef = MeatCategory.objects.get(slug="mol-goshti")
        cat_mutton = MeatCategory.objects.get(slug="qoy-goshti")
        cat_chicken = MeatCategory.objects.get(slug="tovuq-goshti")
        cat_goat = MeatCategory.objects.get(slug="echki-goshti")

        listings = [
            self._listing(s1, market1, cat_beef, "premium-beef", "Premium mol go'shti", "Премиум говядина",
                          "100.00", "50000.00", "Tashkent", soon,
                          "Grass-fed Hereford, same-day delivery in Tashkent.",
                          "Откормленное на травах, доставка в день заказа в Ташкент."),
            self._listing(s1, market1, cat_mutton, "local-mutton", "Mahalliy qo'y go'shti", "Местная баранина",
                          "30.00", "70000.00", "Tashkent", soon,
                          "Young lamb from Surxondaryo region.",
                          "Молодая баранина из Сурхандарьинского региона."),
            self._listing(s2, market2, cat_chicken, "fresh-chicken", "Yangi tovuq go'shti", "Свежая курятина",
                          "60.00", "25000.00", "Samarkand", soon,
                          "Free-range, antibiotic-free.",
                          "Свободный выгул, без антибиотиков."),
            self._listing(s2, market2, cat_goat, "goat-meat", "Echki go'shti", "Козлятина",
                          "20.00", "80000.00", "Samarkand", soon, "", ""),
        ]

        # ---- 4. Sample PENDING order so dashboards aren't empty ----
        b1 = buyers[0]
        first_listing = listings[0]
        Order.objects.get_or_create(buyer=b1, listing=first_listing, defaults={
            "quantity_kg": Decimal("5.00"),
            "total_price": Decimal("5.00") * first_listing.price_per_kg,
            "delivery_address": "Tashkent center, Restoran Aziz",
            "notes": "Please call before delivery",
            "status": Order.Status.PENDING})

        self.stdout.write(self.style.SUCCESS(
            f"Demo data ready — 3 users x 2 roles, 2 markets, {len(listings)} listings, 1 order. "
            f"Password for all: {self.PASSWORD}"))

    # ---------------------------------------------------------------- helpers ----

    def _user(self, email, full_name, role, *, verified=False, business="", region="", address=""):
        """Create or fetch a user; populate the role-specific profile if it isn't already filled."""
        user, created = User.objects.get_or_create(email=email, defaults={"full_name": full_name, "role": role})
        if created:
            user.set_password(self.PASSWORD); user.save(update_fields=("password",))
            self.stdout.write(f"  + created {role} {email}")
        else:
            self.stdout.write(f"  · exists  {role} {email}")
        if role == User.Role.SUPPLIER:
            p = SupplierProfile.objects.get(user=user)
            if not p.business_name: p.business_name = business; p.region = region; p.address = address
            p.is_verified = verified
            p.save()
        elif role == User.Role.BUYER:
            p = BuyerProfile.objects.get(user=user)
            if not p.business_name: p.business_name = business; p.region = region; p.address = address; p.save()
        return user

    def _market(self, slug, name_uz, name_ru, *, region, address, owner):
        """Idempotent Market upsert. owner becomes both created_by and updated_by so the audit trail isn't blank."""
        market, created = Market.objects.get_or_create(slug=slug, defaults={
            "name_uz": name_uz, "name_ru": name_ru, "region": region, "address": address,
            "is_active": True, "created_by": owner, "updated_by": owner})
        self.stdout.write(f"  {'+' if created else '·'} market   {name_uz} ({region})")
        return market

    def _listing(self, supplier, market, category, slug, name_uz, name_ru, qty_kg, price,
                 location, available_from, desc_uz, desc_ru):
        """Idempotent Listing upsert scoped by (market, slug). Sets created_by from the supplier and skips the
        price-history signal via _skip_price_history (seeds shouldn't fill PriceHistory with bootstrap noise)."""
        existing = Listing.objects.filter(market=market, slug=slug).first()
        if existing:
            self.stdout.write(f"  · listing  {name_uz} ({supplier.email})")
            return existing
        listing = Listing(
            supplier=supplier, market=market, category=category, slug=slug,
            name_uz=name_uz, name_ru=name_ru,
            description_uz=desc_uz, description_ru=desc_ru,
            quantity_kg=Decimal(qty_kg), price_per_kg=Decimal(price),
            location=location, available_from=available_from,
            status=Listing.Status.ACTIVE,
            created_by=supplier, updated_by=supplier,
        )
        listing._skip_price_history = True  # don't log seed creation as a "price change"
        listing.save()
        self.stdout.write(f"  + listing  {name_uz} ({supplier.email})")
        return listing
