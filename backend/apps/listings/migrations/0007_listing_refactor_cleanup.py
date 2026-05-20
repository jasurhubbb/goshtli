"""Schema cleanup — final phase of the v3.1 catalog refactor.

After the additive migration (0005) and the data backfill (0006), this migration:
  1. Drops the deprecated columns (title, meat_type, description, halal_certified, freshness_date,
     cold_chain, service_area_csv) — all data was copied into the new columns by 0006.
  2. Makes market + category FKs non-null (backfill guaranteed every row has a value).
  3. Makes name_uz non-null (backfill copied title into it; any blanks are filled with a placeholder).

Reversible — rollback re-adds the dropped columns as nullable (data is lost, but schema is restored).
"""
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("listings", "0006_listing_refactor_backfill"),
        ("markets", "0001_initial"),
    ]

    operations = [
        # 1. Promote market FK to non-null. PROTECT on delete (already set in the model) — keeps Listing rows safe
        #    even if a market is hard-deleted by mistake.
        migrations.AlterField(
            model_name="listing",
            name="market",
            field=models.ForeignKey(
                help_text="The vendor that owns this listing",
                on_delete=django.db.models.deletion.PROTECT,
                related_name="listings",
                to="markets.market",
            ),
        ),
        # 2. Promote category FK to non-null. Same PROTECT semantics.
        migrations.AlterField(
            model_name="listing",
            name="category",
            field=models.ForeignKey(
                help_text="Top-level facet — buyers filter by this",
                on_delete=django.db.models.deletion.PROTECT,
                related_name="listings",
                to="listings.meatcategory",
            ),
        ),
        # 3. Promote name_uz to non-null. Backfill copied title → name_uz for every existing row.
        migrations.AlterField(
            model_name="listing",
            name="name_uz",
            field=models.CharField(max_length=200, verbose_name="name (Uzbek)"),
        ),
        # 4. Drop deprecated columns. Their data was migrated into the new columns by 0006.
        migrations.RemoveField(model_name="listing", name="title"),
        migrations.RemoveField(model_name="listing", name="meat_type"),
        migrations.RemoveField(model_name="listing", name="description"),
        migrations.RemoveField(model_name="listing", name="halal_certified"),
        migrations.RemoveField(model_name="listing", name="freshness_date"),
        migrations.RemoveField(model_name="listing", name="cold_chain"),
        migrations.RemoveField(model_name="listing", name="service_area_csv"),
    ]
