"""Legacy recovery command for promoting an affected phone-registered user to QASSOB.

Background: before v3.8.3 the PhoneRegisterView silently dropped the wizard's `role` field, so every
partner-app signup landed as role=BUYER. Catalog operators are never promoted from public buyer
accounts; use ``provision_catalog_operator`` for them.

This command flips the role and ensures the qassob profile exists with is_verified=True.

Usage on Railway:
  railway run python manage.py promote_to_partner --phone +998901234567 --role QASSOB

Or via Railway shell:
  python manage.py promote_to_partner --phone +998901234567 --role QASSOB
"""
from django.core.management.base import BaseCommand, CommandError

from apps.accounts.models import User


class Command(BaseCommand):
    help = "Recover a phone-registered qassob account that was incorrectly created as BUYER."

    def add_arguments(self, parser):
        parser.add_argument("--phone", required=True,
                            help="E.164 phone number, e.g. +998901234567")
        parser.add_argument("--role", required=True, choices=("QASSOB",), help="Target role")

    def handle(self, *args, **opts):
        phone = opts["phone"]
        role = opts["role"]

        try:
            user = User.objects.get(phone=phone)
        except User.DoesNotExist:
            raise CommandError(f"No user with phone={phone}. Check the number or have them sign up first.")

        prev_role = user.role
        if prev_role == role:
            self.stdout.write(self.style.WARNING(f"User {user.email} (phone={phone}) is already {role}; nothing to do."))
            return

        user.role = role
        user.save(update_fields=["role", "updated_at"])
        self.stdout.write(self.style.SUCCESS(f"Role: {prev_role} → {role}"))

        from apps.qassobs.models import QassobProfile
        profile, created = QassobProfile.objects.get_or_create(
            user=user,
            defaults={"full_name": user.full_name or "", "is_verified": True,
                      "region": "Toshkent", "address": ""})
        if not created and not profile.is_verified:
            profile.is_verified = True
            profile.save(update_fields=["is_verified", "updated_at"])
        self.stdout.write(self.style.SUCCESS(
            f"QassobProfile: {'created' if created else 'verified'} (id={profile.pk})"))

        self.stdout.write(self.style.SUCCESS(
            f"Done. {user.email} can now use /partner/* endpoints as {role}."))
