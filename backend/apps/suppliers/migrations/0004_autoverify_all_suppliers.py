"""v3.8.2 — auto-verify all existing SupplierProfile rows so they can list listings without admin
approval. KYC review queue is deferred; once we ship it, a follow-up migration can revert this for
suppliers added after a chosen cutoff date.
"""
from django.db import migrations


def verify_all(apps, schema_editor):
    SupplierProfile = apps.get_model("suppliers", "SupplierProfile")
    SupplierProfile.objects.filter(is_verified=False).update(is_verified=True)


def unverify_all(apps, schema_editor):
    # Reverse is a no-op for safety — we don't know which rows were originally unverified.
    pass


class Migration(migrations.Migration):
    dependencies = [("suppliers", "0003_supplierprofile_animals_supported_and_more")]
    operations = [migrations.RunPython(verify_all, reverse_code=unverify_all)]
