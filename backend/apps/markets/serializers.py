"""Market serializers — public read shape for the buyer side + admin write shape for the in-app admin page.

v3.3 consolidation: in the in-app admin, Bozor == supplier (one entity). Every new Market auto-gets a backing
SUPPLIER User (Market.owner_user) so admin can pick a Market when creating a listing and the backend resolves
the user transparently. owner_user is exposed read-only so the in-app admin can see who backs each market.
"""
from django.contrib.auth import get_user_model
from rest_framework import serializers

from apps.suppliers.models import SupplierProfile
from .models import Market

User = get_user_model()


class MarketSerializer(serializers.ModelSerializer):
    """Default Market shape — used by GET /api/v1/markets/. Includes the resolved logo/cover URLs so callers
    can render without a second roundtrip. Slug is read-only (auto-derived); admins set name + region + phone.
    owner_user_id is exposed so the in-app admin can map markets → backing users for listing creation."""
    logo_url = serializers.SerializerMethodField()
    cover_url = serializers.SerializerMethodField()
    owner_user_id = serializers.IntegerField(source="owner_user.id", read_only=True)

    class Meta:
        model = Market
        fields = ("id", "slug",
                  "name_uz", "name_ru", "description_uz", "description_ru",
                  "address", "region", "lat", "lng",
                  "phone", "working_hours",
                  "logo_url", "cover_url",
                  "is_active",
                  "owner_user_id",
                  "created_at", "updated_at")
        # slug is server-derived from name_uz on save; created/updated timestamps are server-managed.
        read_only_fields = ("id", "slug", "logo_url", "cover_url", "owner_user_id",
                            "created_at", "updated_at")

    def get_logo_url(self, obj):
        request = self.context.get("request")
        if not obj.logo: return ""
        return request.build_absolute_uri(obj.logo.url) if request else obj.logo.url

    def get_cover_url(self, obj):
        request = self.context.get("request")
        if not obj.cover: return ""
        return request.build_absolute_uri(obj.cover.url) if request else obj.cover.url

    def create(self, validated_data):
        """Auto-create a backing SUPPLIER User for this Market, then link it via Market.owner_user.

        Why: in the in-app admin we treat Bozor as the supplier (one concept). Listings need an FK to a User
        (Listing.supplier) — rather than make admins manage a separate supplier user, we synthesize one per
        Market with a deterministic synthetic email (so re-creating a same-named market is safe). The synthetic
        User gets:
          • unusable password — blocks /auth/login/
          • EMPTY phone — blocks /auth/phone-login/ (the market's contact phone stays only on the Market row,
            so someone entering it on the buyer auth flow won't end up logged in as the market)
          • SupplierProfile auto-verified — listings can attach without flipping a separate verification flag
        """
        # Persist the Market first so the slug exists for the synthetic email
        market = Market.objects.create(**validated_data)
        synth_email = f"market-{market.slug}@market.goshtli.local"
        owner = User.objects.filter(email=synth_email).first()
        if owner is None:
            # Build the User directly (bypassing create_user's password requirement) so the row is unusable
            # by design — no password ever existed for it. Phone stays "" to keep this user out of phone-login.
            owner = User(email=synth_email, full_name=market.name_uz, phone="", role=User.Role.SUPPLIER)
            owner.set_unusable_password()
            owner.save()
        # Auto-verify the supplier profile so admin-created listings clear IsVerifiedSupplier even without
        # the role=ADMIN bypass — also keeps the data consistent if we tighten that bypass later.
        SupplierProfile.objects.update_or_create(user=owner,
                                                 defaults={"business_name": market.name_uz,
                                                           "region": market.region,
                                                           "address": market.address,
                                                           "is_verified": True})
        market.owner_user = owner
        market.save(update_fields=["owner_user"])
        return market

    def update(self, instance, validated_data):
        """Keep the backing SUPPLIER User's denormalized fields in sync with the market when name/region/address
        changes — otherwise admin renaming a market leaves stale display data on its supplier profile.
        Phone is NOT mirrored to the User (see create() — synthetic user.phone stays empty by design)."""
        market = super().update(instance, validated_data)
        if market.owner_user_id:
            SupplierProfile.objects.filter(user=market.owner_user).update(
                business_name=market.name_uz, region=market.region, address=market.address)
        return market
