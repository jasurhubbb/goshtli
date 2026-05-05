"""DRF serializers for accounts — registration validates inputs + hashes password; UserSerializer is the safe public view."""
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from .models import User


class UserSerializer(serializers.ModelSerializer):
    """Public-safe user representation — used by /auth/me/ for read AND PATCH.
    email and role are read-only on this serializer to prevent privilege escalation via PATCH /me/."""
    class Meta:
        model = User
        fields = ("id", "email", "full_name", "phone", "role", "is_active", "created_at", "updated_at")
        # email + role locked: changing email needs a verification flow we haven't built; role changes are admin-only
        read_only_fields = ("id", "email", "role", "is_active", "created_at", "updated_at")


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
