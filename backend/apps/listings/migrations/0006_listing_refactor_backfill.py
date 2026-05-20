"""Data migration — backfill existing Listing rows after the v3.1 schema refactor.

For each existing row this migration:
  1. Ensures a fallback Market exists ("legacy-market") and points the listing at it
  2. Maps the legacy `meat_type` enum (BEEF/MUTTON/...) to the corresponding MeatCategory by slug
  3. Copies `title` → `name_uz` (and into `name_ru` as a placeholder until manual translation)
  4. Copies `description` → `description_uz`
  5. Maps the legacy Status (ACTIVE/SOLD_OUT/INACTIVE) → new Status (ACTIVE/OUT_OF_STOCK/ARCHIVED)

Idempotent: re-running the migration won't double-process (only touches rows that still have empty new fields).
Reversible: rollback nulls the new fields again but leaves rows intact.
"""
from django.db import migrations
from django.utils.text import slugify


# meat_type enum slug → MeatCategory slug. Categories were seeded in migration 0004.
MEAT_TYPE_TO_CATEGORY_SLUG = {
    "BEEF": "mol-goshti",
    "MUTTON": "qoy-goshti",
    "CHICKEN": "tovuq-goshti",
    "GOAT": "echki-goshti",
    "HORSE": "ot-goshti",
    "OTHER": "boshqa",
}

# Legacy Status → new Status. SOLD_OUT keeps semantics under a new name; INACTIVE becomes ARCHIVED.
STATUS_MAP = {"ACTIVE": "ACTIVE", "SOLD_OUT": "OUT_OF_STOCK", "INACTIVE": "ARCHIVED"}


def forwards(apps, schema_editor):
    """Backfill new fields on every existing Listing row. Safe when there are zero rows (test DBs, fresh installs)."""
    Listing = apps.get_model("listings", "Listing")
    MeatCategory = apps.get_model("listings", "MeatCategory")
    Market = apps.get_model("markets", "Market")

    if not Listing.objects.exists():
        return  # Fresh DB — nothing to backfill, skip cleanly

    # 1. Create or fetch the "Legacy" market that orphan listings get attached to.
    legacy_market, _ = Market.objects.get_or_create(
        slug="legacy-market",
        defaults={
            "name_uz": "Eski bozor",
            "name_ru": "Старый рынок",
            "address": "—",
            "region": "Toshkent",
            "is_active": False,  # invisible to buyers; exists only as a parking lot for legacy rows
            "description_uz": "Eski tizimdan ko'chirilgan e'lonlar uchun zaxira bozor.",
            "description_ru": "Резервный рынок для объявлений, перенесённых из старой системы.",
        },
    )

    # 2. Cache category lookups so we don't hit the DB per-row in the loop
    category_by_slug = {c.slug: c for c in MeatCategory.objects.all()}
    fallback_category = category_by_slug.get("boshqa")  # any rare/unknown meat_type lands in "Boshqa"

    # 3. Walk every Listing and fill in the new fields
    updated = []
    for lst in Listing.objects.all().iterator():
        changed = False

        if lst.market_id is None:
            lst.market = legacy_market
            changed = True

        if lst.category_id is None:
            target_slug = MEAT_TYPE_TO_CATEGORY_SLUG.get(lst.meat_type, "boshqa")
            lst.category = category_by_slug.get(target_slug, fallback_category)
            changed = True

        if not lst.name_uz and lst.title:
            lst.name_uz = lst.title
            lst.name_ru = lst.title  # placeholder — translator picks this up in the admin later
            changed = True

        if not lst.description_uz and lst.description:
            lst.description_uz = lst.description
            changed = True

        if not lst.slug and lst.name_uz:
            lst.slug = slugify(lst.name_uz)[:140]
            changed = True

        # Remap legacy Status values to the new enum names
        mapped_status = STATUS_MAP.get(lst.status)
        if mapped_status and lst.status != mapped_status:
            lst.status = mapped_status
            changed = True

        if changed:
            updated.append(lst)

    # Bulk update — much faster than calling save() per row, and skips the model's save() (which is fine here
    # since we don't want the auto-slug logic re-running).
    if updated:
        Listing.objects.bulk_update(
            updated,
            ["market", "category", "name_uz", "name_ru", "description_uz", "slug", "status"],
            batch_size=500,
        )


def backwards(apps, schema_editor):
    """Reversal — null out the new fields. Old data (title/meat_type/description) is still on the row so nothing
    is lost. After this rollback the cleanup migration (0007) shouldn't have applied yet."""
    Listing = apps.get_model("listings", "Listing")
    Listing.objects.update(
        market=None, category=None,
        name_uz="", name_ru="", description_uz="", slug="",
    )


class Migration(migrations.Migration):
    dependencies = [
        ("listings", "0005_listing_refactor_add_fields"),
        ("markets", "0001_initial"),  # need Market table to exist before backfill
    ]
    operations = [migrations.RunPython(forwards, backwards)]
