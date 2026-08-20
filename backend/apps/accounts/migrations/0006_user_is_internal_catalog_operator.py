from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0005_alter_user_role"),
    ]

    operations = [
        migrations.AlterField(
            model_name="user",
            name="role",
            field=models.CharField(
                choices=[
                    ("ADMIN", "Admin"),
                    ("SUPPLIER", "Catalog operator"),
                    ("BUYER", "Buyer"),
                    ("QASSOB", "Qassob"),
                    ("COURIER", "Courier"),
                ],
                default="BUYER",
                max_length=10,
                verbose_name="role",
            ),
        ),
        migrations.AddField(
            model_name="user",
            name="is_internal_catalog_operator",
            field=models.BooleanField(
                default=False,
                help_text="Grants the legacy SUPPLIER account access to the platform's private catalog workspace.",
                verbose_name="internal catalog operator",
            ),
        ),
    ]
