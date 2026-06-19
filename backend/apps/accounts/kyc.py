"""KYC document upload + verification flow.

Partners (SUPPLIER + QASSOB) upload identity documents through the partner-app. Admin reviews each
row in Django Admin (apps.accounts.admin.KYCDocumentAdmin) and flips `is_approved`. A post-save signal
on KYCDocument checks whether the REQUIRED set (PASSPORT + BUSINESS_LICENSE) is fully approved and, if
so, flips the partner's profile.is_verified=True and queues an FCM "Verified" push.

Endpoints:
  POST /api/v1/kyc/        — upload a document (multipart). Replaces existing row of same kind.
  GET  /api/v1/kyc/me/     — list the caller's own documents + per-row approval status.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from rest_framework import generics, permissions, serializers, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from apps.common.permissions import IsPartner
from .models import KYCDocument


class KYCDocumentSerializer(serializers.ModelSerializer):
    """Owner-visible shape. `image_url` is the partner-app accessible URL (R2 in prod, /media/ in dev)."""

    image_url = serializers.SerializerMethodField()

    class Meta:
        model = KYCDocument
        fields = ("id", "kind", "image", "image_url", "is_approved", "admin_notes",
                  "created_at", "updated_at")
        read_only_fields = ("id", "image_url", "is_approved", "admin_notes",
                            "created_at", "updated_at")

    def get_image_url(self, obj):
        if not obj.image: return ""
        req = self.context.get("request")
        return req.build_absolute_uri(obj.image.url) if req else obj.image.url


class KYCListCreateView(generics.GenericAPIView):
    """POST /api/v1/kyc/ — multipart upload; replaces existing row of same kind via update_or_create.
    GET  /api/v1/kyc/me/ — list the caller's own documents.
    """
    permission_classes = (IsPartner,)
    serializer_class = KYCDocumentSerializer
    parser_classes = (MultiPartParser, FormParser)

    def get(self, request):
        qs = KYCDocument.objects.filter(user=request.user)
        return Response(self.get_serializer(qs, many=True).data)

    def post(self, request):
        kind = request.data.get("kind")
        if kind not in KYCDocument.Kind.values:
            return Response({"kind": f"Must be one of {KYCDocument.Kind.values}"},
                             status=status.HTTP_400_BAD_REQUEST)
        image = request.FILES.get("image")
        if not image:
            return Response({"image": "Required."}, status=status.HTTP_400_BAD_REQUEST)
        # Replace existing doc of the same kind so admin doesn't see duplicate pending rows.
        doc, _created = KYCDocument.objects.update_or_create(
            user=request.user, kind=kind,
            defaults={"image": image, "is_approved": False, "admin_notes": ""})
        return Response(self.get_serializer(doc).data, status=status.HTTP_201_CREATED)


# ---------------- Signal — auto-verify on full KYC approval ----------------

# Required documents for a partner to be considered verified. Optional kinds (FACILITY_PHOTO, OTHER)
# don't block; admin can require them on a case-by-case basis via admin_notes.
REQUIRED_KYC_KINDS = {KYCDocument.Kind.PASSPORT, KYCDocument.Kind.BUSINESS_LICENSE}


@receiver(post_save, sender=KYCDocument)
def auto_verify_on_full_kyc_approval(sender, instance, created, **kwargs):
    """When ALL required KYCDocument rows for a partner are approved, flip their profile.is_verified.

    Idempotent — re-saving an already-approved doc is a no-op. Pushes an FCM message via the
    notifications app so the partner-app banner flips from amber to green on next open.
    """
    if not instance.is_approved: return
    user = instance.user
    # Are all required kinds present + approved for this user?
    approved_kinds = set(KYCDocument.objects.filter(user=user, is_approved=True)
                          .values_list("kind", flat=True))
    if not REQUIRED_KYC_KINDS.issubset(approved_kinds): return

    # Flip whichever profile this partner has. We do BOTH if somehow both exist (shouldn't, but defensive).
    flipped = False
    if user.is_qassob and hasattr(user, "qassob_profile"):
        if not user.qassob_profile.is_verified:
            user.qassob_profile.is_verified = True
            user.qassob_profile.save(update_fields=["is_verified", "updated_at"])
            flipped = True
    if user.is_supplier and hasattr(user, "supplier_profile"):
        if not user.supplier_profile.is_verified:
            user.supplier_profile.is_verified = True
            user.supplier_profile.save(update_fields=["is_verified", "updated_at"])
            flipped = True

    if flipped:
        # Notify via in-app + FCM. Wrapped in try so a missing notifications app on a fresh DB doesn't
        # break the signal chain (KYC docs still save; partner just doesn't get the push).
        try:
            from apps.notifications.fcm import send_to_user
            send_to_user(user, title="Tabriklaymiz! 🎉",
                          body="Tasdiqlandi — endi to'liq foydalanishingiz mumkin.",
                          link="/")
        except Exception:
            pass
