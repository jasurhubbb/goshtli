"""Provision a QASSOB account (admin-issued phone + password) from the CLI.

    python manage.py provision_qassob --phone +998901234567 --name "Jasur Ergashev"

If --password is omitted a random 8-char one is generated + printed. Hand the phone + password to the
qassob — they sign in via the partners app (phone + password) and finish their profile in the setup wizard.
Idempotent: re-running with the same phone updates the account (and rotates the password).
"""
from django.core.management.base import BaseCommand, CommandError

from apps.accounts.models import User
from apps.accounts.provisioning import provision_partner_account


class Command(BaseCommand):
    help = "Create or update a role=QASSOB User + QassobProfile with a usable phone+password login."

    def add_arguments(self, parser):
        parser.add_argument("--phone", required=True, help="E.164, e.g. +998901234567")
        parser.add_argument("--name", default="", help="Full name")
        parser.add_argument("--password", default="", help="Omit to auto-generate")

    def handle(self, *_, **opts):
        phone = opts["phone"].strip()
        if not phone.startswith("+"):
            raise CommandError("--phone must be E.164 and start with '+', e.g. +998901234567")
        user, password, created = provision_partner_account(
            phone=phone, full_name=opts["name"], role=User.Role.QASSOB, password=opts["password"])
        self.stdout.write(self.style.SUCCESS(f"\n{'Created' if created else 'Updated'} qassob {phone}"))
        self.stdout.write(f"  Password:  {password}")
        self.stdout.write(f"  Full name: {user.full_name}\n")
