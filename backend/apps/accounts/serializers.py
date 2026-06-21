"""DRF serializers for accounts — registration validates inputs + hashes password; UserSerializer is the safe public view."""
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from .models import User


class UserSerializer(serializers.ModelSerializer):
    """Public-safe user representation — used by /auth/me/ for read AND PATCH.
    email and role are read-only on this serializer to prevent privilege escalation via PATCH /me/.

    v3.3: exposes first_name, last_name, patronymic, date_of_birth, gender so the buyer profile-settings screen
    can edit them. full_name stays writable for back-compat, BUT if the request supplies first_name or last_name
    we recompute full_name as "{last} {first}" inside update() so the legacy display string never drifts from
    the structured fields."""
    class Meta:
        model = User
        fields = ("id", "email", "full_name", "phone", "role", "is_active",
                  "first_name", "last_name", "patronymic", "date_of_birth", "gender",
                  "created_at", "updated_at")
        # email + role locked: changing email needs a verification flow we haven't built; role changes are admin-only
        read_only_fields = ("id", "email", "role", "is_active", "created_at", "updated_at")

    def update(self, instance, validated_data):
        # Sync full_name when the client supplies the structured pieces — avoids two screens of state to keep aligned.
        # If neither first_name nor last_name is in this PATCH, leave full_name as-is (client may PATCH it directly).
        if "first_name" in validated_data or "last_name" in validated_data:
            last = validated_data.get("last_name", instance.last_name)
            first = validated_data.get("first_name", instance.first_name)
            combined = f"{last} {first}".strip()
            if combined:                                       # only overwrite when we have something meaningful
                validated_data["full_name"] = combined
        return super().update(instance, validated_data)


class RegisterSerializer(serializers.ModelSerializer):
    """Handles POST /auth/register — validates password against Django's strength rules and creates the user via manager."""
    # write_only ensures the password never appears in the response body
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password], min_length=8)
    # Only allow self-registration as supplier or buyer; ADMIN is created via createsuperuser (not the public API)
    role = serializers.ChoiceField(choices=[(User.Role.SUPPLIER, "Supplier"), (User.Role.BUYER, "Buyer")])

    class Meta:
        model = User
        fields = ("id", "email", "full_name", "phone", "role", "password")
        read_only_fields = ("id",)

    def create(self, validated_data):
        # Delegate to UserManager so password hashing and email normalization stay in one place
        return User.objects.create_user(**validated_data)


# ---------- Phone-based auth (v3.2 buyer flow) ----------

class PhoneCheckSerializer(serializers.Serializer):
    """Inbound shape for POST /auth/phone-check/ — accepts a single phone string and validates the basic
    international-format shape (must start with + and have 10-15 digits). Real OTP verification is a follow-up;
    for v3.2 we trust the client to provide a real number."""
    phone = serializers.RegexField(
        regex=r'^\+[0-9]{10,15}$',
        max_length=20,
        error_messages={'invalid': 'Phone must be in +<digits> international format.'},
    )


class PhoneRegisterSerializer(serializers.Serializer):
    """Inbound shape for POST /auth/phone-register/ — phone + name (required) + business_name (optional).
    business_name lands on BuyerProfile via the post-create signal; no separate write needed here.

    v3.8.3: `role` is now accepted (optional, defaults to BUYER) so the partner-app wizard can register
    its supplier / qassob accounts with the correct role. Previously this field was silently dropped
    and every phone-registered user landed as BUYER — including partners — which broke the
    role-conditional UI in the partner app (e.g. "Sotadigan go'shtlar" row hidden for suppliers).
    Restricted to the three legitimate self-signup roles; ADMIN is provisioned out-of-band only.
    """
    phone = serializers.RegexField(regex=r'^\+[0-9]{10,15}$', max_length=20)
    full_name = serializers.CharField(max_length=150, min_length=1)
    business_name = serializers.CharField(max_length=200, required=False, allow_blank=True)
    role = serializers.ChoiceField(choices=("BUYER", "SUPPLIER", "QASSOB"),
                                   default="BUYER", required=False)
