"""Provision a SUPPLIER account (admin-issued phone + password) from the CLI.

    python manage.py provision_supplier --phone +998901234567 --name "Akmal Karimov" \
                                        --business "Karimov Go'sht"

If --password is omitted a random 8-char one is generated + printed. Hand the phone + password to the
supplier — they sign in via the partners app (phone + password) and finish their profile in the setup wizard.
Idempotent: re-running with the same phone updates the account (and rotates the password).
"""
from django.core.management.base import BaseCommand, CommandError

from apps.accounts.models import User
from apps.accounts.provisioning import provision_partner_account


class Command(BaseCommand):
    help = "Create or update a role=SUPPLIER User + SupplierProfile with a usable phone+password login."

    def add_arguments(self, parser):
        parser.add_argument("--phone", required=True, help="E.164, e.g. +998901234567")
        parser.add_argument("--name", default="", help="Operator full name")
        parser.add_argument("--business", default="", help="Business / shop name")
        parser.add_argument("--password", default="", help="Omit to auto-generate")

    def handle(self, *_, **opts):
        phone = opts["phone"].strip()
        if not phone.startswith("+"):
            raise CommandError("--phone must be E.164 and start with '+', e.g. +998901234567")
        user, password, created = provision_partner_account(
            phone=phone, full_name=opts["name"], role=User.Role.SUPPLIER,
            password=opts["password"], business_name=opts["business"])
        self.stdout.write(self.style.SUCCESS(f"\n{'Created' if created else 'Updated'} supplier {phone}"))
        self.stdout.write(f"  Password:  {password}")
        self.stdout.write(f"  Full name: {user.full_name}")
        self.stdout.write(f"  Business:  {opts['business']}\n")
