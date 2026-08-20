"""Provision a private platform catalog-operator account.

The persisted role remains SUPPLIER for compatibility with listing ownership and partner APIs, but
this command is intentionally named after the account's real purpose:

    python manage.py provision_catalog_operator --phone +998901234567 \
        --name "Catalog Team" --password "a-strong-password"

If ``--password`` is omitted, a random password is generated and printed once. Re-running the
command for the same phone updates the account and rotates its password.
"""
from django.core.management.base import BaseCommand, CommandError

from apps.accounts.models import User
from apps.accounts.provisioning import provision_partner_account
from apps.suppliers.models import SupplierProfile


class Command(BaseCommand):
    help = "Create or update a private platform catalog operator with phone/password access."

    def add_arguments(self, parser):
        parser.add_argument("--phone", required=True, help="E.164, e.g. +998901234567")
        parser.add_argument("--name", default="Catalog Team", help="Operator or team name")
        parser.add_argument("--password", default="", help="Omit to auto-generate")

    def handle(self, *_, **opts):
        phone = opts["phone"].strip()
        if not phone.startswith("+"):
            raise CommandError("--phone must be E.164 and start with '+', e.g. +998901234567")

        name = opts["name"].strip() or "Catalog Team"
        user, password, created = provision_partner_account(
            phone=phone, full_name=name, role=User.Role.SUPPLIER,
            password=opts["password"], business_name="Platform Catalog")
        SupplierProfile.objects.filter(user=user).update(
            business_name="Platform Catalog", is_verified=True)

        action = "Created" if created else "Updated"
        self.stdout.write(self.style.SUCCESS(f"\n{action} catalog operator {phone}"))
        self.stdout.write(f"  Password: {password}")
        self.stdout.write(f"  Name:     {user.full_name}\n")
