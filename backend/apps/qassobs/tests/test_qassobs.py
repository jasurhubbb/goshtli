"""Qassob endpoint matrix — profile CRUD, public discovery, availability + capacity toggles.

Run with: pytest apps/qassobs/tests/
"""
from decimal import Decimal

import pytest
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import User
from apps.qassobs.models import QassobProfile


# ---------------- Helpers ----------------

def _client_for(user):
    c = APIClient()
    c.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return c


@pytest.fixture
def qassob_user(db):
    return User.objects.create_user(email="q1@test.local", password="X", full_name="Qassob One",
                                     role=User.Role.QASSOB, phone="+998901111111")


@pytest.fixture
def qassob_client(qassob_user): return _client_for(qassob_user)


@pytest.fixture
def buyer_only_user(db):
    return User.objects.create_user(email="b1@test.local", password="X", full_name="Buyer", role=User.Role.BUYER)


def _wizard_payload():
    return {
        "full_name": "Anvar Karimov",
        "years_experience": 10,
        "region": "Tashkent",
        "address": "Yunusobod 1",
        "lat": "41.3680", "lng": "69.2873",
        "service_radius_km": 25,
        "animals_supported": ["MOL", "QOY"],
        "is_slaughterhouse": True,
        "daily_capacity_head": 8,
        "phone_visible": True,
        "telegram_username": "anvarq",
    }


# ---------------- Owner CRUD (/qassobs/me/) ----------------

@pytest.mark.django_db
class TestQassobMe:
    URL = "/api/v1/qassobs/me/"

    def test_anonymous_blocked(self, api):
        r = api.post(self.URL, _wizard_payload(), format="json")
        assert r.status_code == 401

    def test_buyer_role_blocked(self, buyer_only_user):
        c = _client_for(buyer_only_user)
        r = c.post(self.URL, _wizard_payload(), format="json")
        assert r.status_code == 403

    def test_qassob_post_creates_profile(self, qassob_client, qassob_user):
        r = qassob_client.post(self.URL, _wizard_payload(), format="json")
        assert r.status_code == 201
        assert r.data["full_name"] == "Anvar Karimov"
        assert r.data["years_experience"] == 10
        assert r.data["is_verified"] is False
        assert r.data["animals_supported"] == ["MOL", "QOY"]
        assert QassobProfile.objects.filter(user=qassob_user).exists()

    def test_double_post_409(self, qassob_client):
        qassob_client.post(self.URL, _wizard_payload(), format="json")
        r = qassob_client.post(self.URL, _wizard_payload(), format="json")
        assert r.status_code == 409

    def test_patch_edits(self, qassob_client):
        qassob_client.post(self.URL, _wizard_payload(), format="json")
        r = qassob_client.patch(self.URL, {"years_experience": 20, "daily_capacity_head": 15},
                                 format="json")
        assert r.status_code == 200
        assert r.data["years_experience"] == 20
        assert r.data["daily_capacity_head"] == 15

    def test_get_returns_profile(self, qassob_client):
        qassob_client.post(self.URL, _wizard_payload(), format="json")
        r = qassob_client.get(self.URL)
        assert r.status_code == 200
        assert r.data["full_name"] == "Anvar Karimov"

    def test_get_404_before_create(self, qassob_client):
        r = qassob_client.get(self.URL)
        assert r.status_code == 404

    def test_bad_animal_code_rejected(self, qassob_client):
        payload = _wizard_payload()
        payload["animals_supported"] = ["MOL", "TURKEY"]
        r = qassob_client.post(self.URL, payload, format="json")
        assert r.status_code == 400


# ---------------- Availability + capacity ----------------

@pytest.mark.django_db
class TestQassobToggles:
    def test_availability_toggle(self, qassob_client):
        qassob_client.post("/api/v1/qassobs/me/", _wizard_payload(), format="json")
        r = qassob_client.post("/api/v1/qassobs/me/availability/", {"is_open_now": False}, format="json")
        assert r.status_code == 200 and r.data["is_open_now"] is False
        assert QassobProfile.objects.get().is_open_now is False

    def test_capacity_update(self, qassob_client):
        qassob_client.post("/api/v1/qassobs/me/", _wizard_payload(), format="json")
        r = qassob_client.post("/api/v1/qassobs/me/capacity/", {"daily_capacity_head": 25}, format="json")
        assert r.status_code == 200 and r.data["daily_capacity_head"] == 25

    def test_capacity_clamped(self, qassob_client):
        qassob_client.post("/api/v1/qassobs/me/", _wizard_payload(), format="json")
        r = qassob_client.post("/api/v1/qassobs/me/capacity/", {"daily_capacity_head": 999}, format="json")
        assert r.status_code == 400


# ---------------- Public discovery ----------------

@pytest.mark.django_db
class TestQassobList:
    URL = "/api/v1/qassobs/"

    def test_unverified_hidden(self, api, qassob_client):
        qassob_client.post("/api/v1/qassobs/me/", _wizard_payload(), format="json")
        r = api.get(self.URL)
        assert r.status_code == 200
        assert r.data == []                                  # is_verified=False → hidden

    def test_verified_visible(self, api, qassob_user, qassob_client):
        qassob_client.post("/api/v1/qassobs/me/", _wizard_payload(), format="json")
        QassobProfile.objects.filter(user=qassob_user).update(is_verified=True)
        r = api.get(self.URL)
        assert r.status_code == 200
        assert len(r.data) == 1
        assert r.data[0]["full_name"] == "Anvar Karimov"

    def test_filter_by_animal(self, api, qassob_user, qassob_client):
        qassob_client.post("/api/v1/qassobs/me/", _wizard_payload(), format="json")
        QassobProfile.objects.filter(user=qassob_user).update(is_verified=True)
        r = api.get(f"{self.URL}?animal=MOL")
        assert r.status_code == 200 and len(r.data) == 1
        r2 = api.get(f"{self.URL}?animal=TOVUQ")
        assert r2.status_code == 200 and len(r2.data) == 0

    def test_filter_by_service_slaughter(self, api, qassob_user, qassob_client):
        qassob_client.post("/api/v1/qassobs/me/", _wizard_payload(), format="json")
        QassobProfile.objects.filter(user=qassob_user).update(is_verified=True)
        r = api.get(f"{self.URL}?service=slaughter")
        assert r.status_code == 200 and len(r.data) == 1     # is_slaughterhouse=True

    def test_distance_km_computed(self, api, qassob_user, qassob_client):
        qassob_client.post("/api/v1/qassobs/me/", _wizard_payload(), format="json")
        QassobProfile.objects.filter(user=qassob_user).update(is_verified=True)
        r = api.get(f"{self.URL}?buyer_lat=41.3000&buyer_lng=69.2500")
        assert r.status_code == 200
        d = r.data[0].get("distance_km")
        assert d is not None and 0 < d < 50

    def test_closed_hidden(self, api, qassob_user, qassob_client):
        qassob_client.post("/api/v1/qassobs/me/", _wizard_payload(), format="json")
        QassobProfile.objects.filter(user=qassob_user).update(is_verified=True, is_open_now=False)
        r = api.get(self.URL)
        assert r.status_code == 200 and r.data == []
        # include_closed=1 brings them back
        r2 = api.get(f"{self.URL}?include_closed=1")
        assert r2.status_code == 200 and len(r2.data) == 1
