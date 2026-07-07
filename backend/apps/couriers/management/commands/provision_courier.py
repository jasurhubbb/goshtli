"""Provision a courier account from the CLI.

    python manage.py provision_courier --email jamshid@go-sht.uz --name "Jamshid Ergashev" \
                                        --phone +998990001111

If --password is omitted, a random 8-char code is generated + printed. Hand this to the courier
along with the email — they log in via the partner-app's "Delivery" role card.
"""
import secrets

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from apps.couriers.models import CourierProfile


class Command(BaseCommand):
    help = "Create or update a role=COURIER User + CourierProfile."

    def add_arguments(self, parser):
        parser.add_argument("--email", required=True)
        parser.add_argument("--name", default="")
        parser.add_argument("--phone", default="")
        parser.add_argument("--password", default="")
        parser.add_argument("--vehicle", default="BIKE",
                            help="One of BIKE / CAR / VAN / REFRIGERATOR / CHORVA_TAXI")
        parser.add_argument("--plate", default="")

    def handle(self, *_, **opts):
        User = get_user_model()
        email = opts["email"].strip().lower()
        pw = opts["password"] or secrets.token_urlsafe(6)[:8]

        user, created = User.objects.get_or_create(
            email=email, defaults={"full_name": opts["name"], "phone": opts["phone"],
                                    "role": User.Role.COURIER})
        if not created:
            user.role = User.Role.COURIER
            if opts["name"]: user.full_name = opts["name"]
            if opts["phone"]: user.phone = opts["phone"]
        user.set_password(pw)
        user.save()

        profile, _ = CourierProfile.objects.get_or_create(
            user=user, defaults={"full_name": user.full_name or ""})
        profile.vehicle_kind = opts["vehicle"]
        profile.vehicle_plate = opts["plate"]
        profile.save(update_fields=("vehicle_kind", "vehicle_plate", "updated_at"))

        self.stdout.write(self.style.SUCCESS(
            f"\n{'Created' if created else 'Updated'} courier {email}"))
        self.stdout.write(f"  Password: {pw}")
        self.stdout.write(f"  Vehicle:  {opts['vehicle']} {opts['plate']}")
        self.stdout.write(f"  Full name: {user.full_name}")
        self.stdout.write(f"  Phone:    {user.phone}\n")
