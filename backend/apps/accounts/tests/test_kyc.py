"""KYC upload + auto-verify signal."""
from io import BytesIO

import pytest
from PIL import Image
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import KYCDocument, User
from apps.qassobs.models import QassobProfile


def _client_for(user):
    c = APIClient()
    c.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return c


def _png(name="doc.png"):
    """Minimal in-memory PNG so MultiPartParser accepts the upload."""
    buf = BytesIO()
    Image.new("RGB", (4, 4), color=(0, 0, 0)).save(buf, "PNG")
    buf.seek(0); buf.name = name
    return buf


@pytest.fixture
def qassob_user(db):
    u = User.objects.create_user(email="kq@test.local", password="X", full_name="K Q",
                                  role=User.Role.QASSOB, phone="+998904444444")
    QassobProfile.objects.create(user=u, full_name="K Q", years_experience=5,
                                   region="Tashkent", address="addr",
                                   animals_supported=["MOL"], daily_capacity_head=5)
    return u


@pytest.mark.django_db
class TestKYC:
    URL = "/api/v1/kyc/"

    def test_upload_passport(self, qassob_user):
        c = _client_for(qassob_user)
        r = c.post(self.URL, {"kind": "PASSPORT", "image": _png()}, format="multipart")
        assert r.status_code == 201
        assert r.data["kind"] == "PASSPORT"
        assert r.data["is_approved"] is False

    def test_upload_replaces_existing(self, qassob_user):
        c = _client_for(qassob_user)
        c.post(self.URL, {"kind": "PASSPORT", "image": _png("a.png")}, format="multipart")
        r = c.post(self.URL, {"kind": "PASSPORT", "image": _png("b.png")}, format="multipart")
        assert r.status_code == 201
        assert KYCDocument.objects.filter(user=qassob_user, kind="PASSPORT").count() == 1

    def test_buyer_blocked(self, db):
        buyer = User.objects.create_user(email="bb@test.local", password="X", full_name="B",
                                          role=User.Role.BUYER)
        c = _client_for(buyer)
        r = c.post(self.URL, {"kind": "PASSPORT", "image": _png()}, format="multipart")
        assert r.status_code == 403

    def test_bad_kind_rejected(self, qassob_user):
        c = _client_for(qassob_user)
        r = c.post(self.URL, {"kind": "INVALID", "image": _png()}, format="multipart")
        assert r.status_code == 400

    def test_signal_flips_verified_when_both_required_approved(self, qassob_user):
        c = _client_for(qassob_user)
        c.post(self.URL, {"kind": "PASSPORT", "image": _png()}, format="multipart")
        c.post(self.URL, {"kind": "BUSINESS_LICENSE", "image": _png()}, format="multipart")
        assert qassob_user.qassob_profile.is_verified is False
        # Admin approves both
        for doc in KYCDocument.objects.filter(user=qassob_user):
            doc.is_approved = True
            doc.save(update_fields=["is_approved", "updated_at"])
        qassob_user.qassob_profile.refresh_from_db()
        assert qassob_user.qassob_profile.is_verified is True
