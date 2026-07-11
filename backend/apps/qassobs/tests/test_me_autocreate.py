"""A qassob created via the Django-admin 'Add user' form (User only, no QassobProfile) must still work in
the app: GET /qassobs/me/ auto-creates the profile so the tabs don't 404 with 'profil topilmadi'."""
import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.qassobs.models import QassobProfile

pytestmark = pytest.mark.django_db


def _qassob_user():
    # Mirrors the admin "Add user" path: a role=QASSOB User with NO profile.
    return User.objects.create(email="q@phone.goshtli.local", phone="+998901112233",
                               full_name="Admin Made Qassob", role=User.Role.QASSOB)


def test_get_me_autocreates_profile_for_admin_made_qassob():
    u = _qassob_user()
    assert not QassobProfile.objects.filter(user=u).exists()   # admin form made no profile

    client = APIClient(); client.force_authenticate(u)
    r = client.get("/api/v1/qassobs/me/")
    assert r.status_code == 200, r.data                        # was 404 before the fix
    assert QassobProfile.objects.filter(user=u).exists()       # now auto-created
    # Empty animals_supported → the app routes them into the setup wizard on login.
    assert r.data.get("animals_supported") in ([], None)


def test_post_me_upserts_instead_of_409():
    u = _qassob_user()
    client = APIClient(); client.force_authenticate(u)
    client.get("/api/v1/qassobs/me/")                          # auto-creates the empty profile
    # The wizard's submit POSTs the profile — must UPDATE the auto-created row, not 409.
    r = client.post("/api/v1/qassobs/me/",
                    {"full_name": "Jasur", "region": "Toshkent", "address": "Sarvarbek",
                     "animals_supported": ["MOL", "QOY"]}, format="json")
    assert r.status_code == 200, r.data
    p = QassobProfile.objects.get(user=u)
    assert p.region == "Toshkent" and p.animals_supported == ["MOL", "QOY"]
