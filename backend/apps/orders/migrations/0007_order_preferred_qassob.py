"""v3.9.15 — preferred_qassob FK on Order.

Buyers can request a specific qassob when checking out a live-animal cart. The FK is nullable
so pre-v3.9.15 orders continue to load, and SET_NULL so cancelling a qassob's account doesn't
cascade-delete history. The auto-assignment / dispatch logic reads this field first before
falling back to the fan-out pool.
"""
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('orders', '0006_alter_order_status'),
    ]

    operations = [
        migrations.AddField(
            model_name='order',
            name='preferred_qassob',
            field=models.ForeignKey(blank=True, db_index=True, null=True,
                                    on_delete=models.SET_NULL,
                                    related_name='preferred_qassob_orders',
                                    to=settings.AUTH_USER_MODEL),
        ),
    ]
