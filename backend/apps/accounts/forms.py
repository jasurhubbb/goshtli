"""Admin forms for the custom email-based User.

v3.9.16 — only ADMIN accounts need a real email. Buyers / suppliers / qassobs / couriers are phone-first,
so the Django-admin "Add user" form makes email OPTIONAL and synthesizes a placeholder from the phone
(same shape as UserManager.create_user_from_phone: "<digits>@phone.goshtli.local"). Leave email blank and
just give a phone. Admins who want to log into Django Admin can still type a real email.
"""
from django import forms
from django.contrib.auth.forms import UserCreationForm

from .models import User


def synth_email_from_phone(phone: str) -> str:
    """Deterministic placeholder email for a phone-only account. Unique because phone is unique."""
    return f"{phone.lstrip('+')}@phone.goshtli.local"


class AdminUserCreationForm(UserCreationForm):
    """Add-user form with an OPTIONAL email. If email is blank we require a phone and synthesize the email
    from it, so ops can create suppliers/qassobs/couriers without inventing an email address."""

    class Meta:
        model = User
        fields = ("email", "full_name", "phone", "role", "is_staff", "is_superuser")

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if "email" in self.fields:
            self.fields["email"].required = False
        if "phone" in self.fields:
            self.fields["phone"].help_text = ("Required if email is left blank — the login email is "
                                              "synthesized from the phone for non-admin users.")

    def clean(self):
        cleaned = super().clean()
        email = (cleaned.get("email") or "").strip()
        phone = (cleaned.get("phone") or "").strip()
        # Set the synthesized email in clean() so model validation (email is NOT NULL) sees a value.
        if not email:
            if not phone:
                raise forms.ValidationError("Provide a phone number (email is optional for non-admin users).")
            cleaned["email"] = synth_email_from_phone(phone)
        return cleaned

    def save(self, commit=True):
        user = super().save(commit=False)
        if not user.email:                                    # belt-and-suspenders if clean() was bypassed
            user.email = synth_email_from_phone((self.cleaned_data.get("phone") or "").strip())
        if commit:
            user.save()
        return user
