"""v3.8.2 — auto-verify all existing QassobProfile rows. Same rationale as suppliers/0004.
"""
from django.db import migrations


def verify_all(apps, schema_editor):
    QassobProfile = apps.get_model("qassobs", "QassobProfile")
    QassobProfile.objects.filter(is_verified=False).update(is_verified=True)


def unverify_all(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [("qassobs", "0001_initial")]
    operations = [migrations.RunPython(verify_all, reverse_code=unverify_all)]
