"""Data migration — create the two catalog-staff Django Groups + assign their base permissions.

Groups (mirrors the RBAC story in the admin layer):
  • Catalog Editor    — can add + change Listings, Markets, MeatCategories; CANNOT change Listing.status
                        or hard-delete anything (enforced via admin's get_readonly_fields + has_delete_permission).
  • Catalog Publisher — Editor + can change Listing.status (publish/archive); still no hard delete.

Hard delete + sensitive admin actions (changing user roles, viewing audit log, etc.) remain superuser-only.

Reversible: rollback removes both groups.
"""
from django.db import migrations


EDITOR_PERMS = [
    # (app_label, model_name, codename) — keep this list narrow so adding a new model doesn't accidentally
    # grant Editor write access to it. Add explicitly when needed.
    ("listings", "listing", "add_listing"),
    ("listings", "listing", "change_listing"),
    ("listings", "listing", "view_listing"),
    ("listings", "meatcategory", "add_meatcategory"),
    ("listings", "meatcategory", "change_meatcategory"),
    ("listings", "meatcategory", "view_meatcategory"),
    ("listings", "listingphoto", "add_listingphoto"),
    ("listings", "listingphoto", "change_listingphoto"),
    ("listings", "listingphoto", "delete_listingphoto"),   # photos can be removed; the listing row itself cannot
    ("listings", "listingphoto", "view_listingphoto"),
    ("listings", "pricehistory", "view_pricehistory"),     # read-only — signal creates the rows
    ("markets", "market", "add_market"),
    ("markets", "market", "change_market"),
    ("markets", "market", "view_market"),
]

# Publishers get everything Editors do, plus the ability to flip Listing.status (the admin layer enforces the
# field-level restriction by checking group membership in get_readonly_fields). Since Django's permission model
# is model-level, the group just signals "this user is a publisher" — admin reads it.
PUBLISHER_PERMS = EDITOR_PERMS  # same model-level perms; field-level gate is in admin.get_readonly_fields


def forwards(apps, schema_editor):
    """Create both groups + attach the listed Permission rows. Idempotent: rerunning is safe."""
    Group = apps.get_model("auth", "Group")
    Permission = apps.get_model("auth", "Permission")

    def _build(group_name, perm_specs):
        group, _ = Group.objects.get_or_create(name=group_name)
        perms = []
        for app_label, model, codename in perm_specs:
            try:
                perms.append(Permission.objects.get(
                    content_type__app_label=app_label, content_type__model=model, codename=codename))
            except Permission.DoesNotExist:
                # Permission doesn't exist yet — skipping (would happen if a model migration was rolled back
                # since these RBAC groups were created). Safe to ignore; next migrate run will pick it up.
                continue
        group.permissions.set(perms)
        return group

    _build("Catalog Editor", EDITOR_PERMS)
    _build("Catalog Publisher", PUBLISHER_PERMS)


def backwards(apps, schema_editor):
    """Remove the two groups on rollback. User → group assignments are cleaned up automatically by the M2M."""
    Group = apps.get_model("auth", "Group")
    Group.objects.filter(name__in=["Catalog Editor", "Catalog Publisher"]).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("listings", "0009_historicallisting"),
        ("markets", "0002_historicalmarket"),
        # auth migrations must have run so Permission rows exist for the models we reference
        ("auth", "0012_alter_user_first_name_max_length"),
    ]
    operations = [migrations.RunPython(forwards, backwards)]
