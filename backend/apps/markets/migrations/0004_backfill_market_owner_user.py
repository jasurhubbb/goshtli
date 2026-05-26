"""Data migration: backfill Market.owner_user for any market created before v3.3.

Why: MarketSerializer.create() auto-creates a backing SUPPLIER user for new markets, but markets created
earlier (seed_demo demo data, Django Admin entries) have owner_user=NULL. The admin "Yangi e'lon" path
needs market.owner_user to resolve the Listing.supplier FK — without it, every POST /listings/ fails with
"This market has no backing supplier user. Recreate it."

This migration walks every Market(owner_user__isnull=True) and creates a synthetic SUPPLIER user with the
same shape MarketSerializer.create produces:
  • synthetic email "market-<slug>@market.goshtli.local"
  • unusable password (blocks /auth/login/)
  • empty phone (blocks /auth/phone-login/ for this synthetic user — the market's contact phone stays
    only on the Market row)
  • auto-verified SupplierProfile (so listings can attach without admin's IsVerifiedSupplier bypass)

Idempotent: skips markets that already have owner_user, and get_or_creates the synthetic User by email so
re-running this migration on a partially-backfilled DB is safe.
"""
from django.db import migrations


def backfill_owner_user(apps, schema_editor):
    Market = apps.get_model("markets", "Market")
    User = apps.get_model("accounts", "User")
    SupplierProfile = apps.get_model("suppliers", "SupplierProfile")

    # Pull the Role enum values out as raw strings — historical models don't carry TextChoices methods
    SUPPLIER_ROLE = "SUPPLIER"

    for market in Market.objects.filter(owner_user__isnull=True):
        synth_email = f"market-{market.slug or market.pk}@market.goshtli.local"
        owner, created = User.objects.get_or_create(
            email=synth_email,
            defaults={
                "full_name": market.name_uz,
                "phone": "",
                "role": SUPPLIER_ROLE,
                "is_active": True,
                "is_staff": False,
                "is_superuser": False,
                # set_unusable_password produces a hash starting with "!" — Django treats it as no-login
                "password": "!unusable",
            },
        )
        # Ensure a verified SupplierProfile mirrors the market for listing creation
        SupplierProfile.objects.update_or_create(
            user=owner,
            defaults={
                "business_name": market.name_uz,
                "region": market.region,
                "address": market.address,
                "is_verified": True,
            },
        )
        market.owner_user = owner
        market.save(update_fields=["owner_user"])


def noop_reverse(apps, schema_editor):
    """Reverse: don't undo. The synthetic users + supplier profiles may have listings/orders attached by
    now, and the easiest production-safe rollback is to leave them in place."""
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("markets", "0003_historicalmarket_owner_user_market_owner_user"),
        ("accounts", "0003_user_date_of_birth_user_first_name_user_gender_and_more"),
        ("suppliers", "0002_supplierprofile_description_and_more"),
    ]

    operations = [
        migrations.RunPython(backfill_owner_user, reverse_code=noop_reverse),
    ]
