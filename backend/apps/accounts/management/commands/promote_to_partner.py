"""Promote a phone-registered user from BUYER to SUPPLIER or QASSOB.

Background: before v3.8.3 the PhoneRegisterView silently dropped the wizard's `role` field, so every
partner-app signup landed as role=BUYER. That makes /partner/inbox/ + every IsPartner-gated endpoint
403 for the affected user, even though they have a SupplierProfile / QassobProfile under the hood.

This command flips the role + (re-)ensures the role-specific profile exists with is_verified=True so
the supplier can immediately create listings and receive orders.

Usage on Railway:
  railway run python manage.py promote_to_partner --phone +998901234567 --role SUPPLIER

Or via Railway shell:
  python manage.py promote_to_partner --phone +998901234567 --role SUPPLIER
"""
from django.core.management.base import BaseCommand, CommandError

from apps.accounts.models import User


class Command(BaseCommand):
    help = "Flip a phone-registered user's role to SUPPLIER or QASSOB and ensure the matching profile exists."

    def add_arguments(self, parser):
        parser.add_argument("--phone", required=True,
                            help="E.164 phone number, e.g. +998901234567")
        parser.add_argument("--role", required=True, choices=("SUPPLIER", "QASSOB"),
                            help="Target role")

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

        # Ensure the role-specific profile exists + is verified. Without this the user still
        # 403s on listing creation because their profile is_verified=False (only the v3.8.2
        # signal sets it on creation, and the signal only fires for role=SUPPLIER).
        if role == "SUPPLIER":
            from apps.suppliers.models import SupplierProfile
            profile, created = SupplierProfile.objects.get_or_create(
                user=user, defaults={"business_name": "", "is_verified": True})
            if not created and not profile.is_verified:
                profile.is_verified = True
                profile.save(update_fields=["is_verified", "updated_at"])
            self.stdout.write(self.style.SUCCESS(
                f"SupplierProfile: {'created' if created else 'verified'} (id={profile.pk})"))
        else:
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
