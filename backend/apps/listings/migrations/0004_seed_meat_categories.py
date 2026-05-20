"""Data migration — seed the 8 launch meat categories. Reversible: rollback wipes them.

Categories are picked to cover the Uzbek market's primary cuts. `display_order` leaves gaps (10, 20, 30, ...) so
admins can insert new categories between existing ones later without renumbering.

Images are intentionally left null — workers upload the actual product photos via Django Admin after migration.
"""
from django.db import migrations


# (slug, name_uz, name_ru, display_order)
SEED_CATEGORIES = [
    ("mol-goshti",   "Mol go'shti",    "Говядина",    10),
    ("qoy-goshti",   "Qo'y go'shti",   "Баранина",    20),
    ("tovuq-goshti", "Tovuq go'shti",  "Курятина",    30),
    ("echki-goshti", "Echki go'shti",  "Козлятина",   40),
    ("ot-goshti",    "Ot go'shti",     "Конина",      50),
    ("qiyma",        "Qiyma",          "Фарш",        60),
    ("jigar",        "Jigar",          "Печень",      70),
    ("boshqa",       "Boshqa",         "Другое",      80),
]


def forwards(apps, schema_editor):
    """Insert all 8 categories. Uses get_or_create on slug so re-running is idempotent (safe to migrate twice)."""
    MeatCategory = apps.get_model("listings", "MeatCategory")
    for slug, name_uz, name_ru, order in SEED_CATEGORIES:
        MeatCategory.objects.update_or_create(
            slug=slug,
            defaults={"name_uz": name_uz, "name_ru": name_ru, "display_order": order, "is_active": True},
        )


def backwards(apps, schema_editor):
    """Remove all 8 seeded categories on rollback. Won't touch any admin-added categories with other slugs."""
    MeatCategory = apps.get_model("listings", "MeatCategory")
    MeatCategory.objects.filter(slug__in=[s for s, *_ in SEED_CATEGORIES]).delete()


class Migration(migrations.Migration):
    dependencies = [("listings", "0003_add_meat_category")]
    operations = [migrations.RunPython(forwards, backwards)]
