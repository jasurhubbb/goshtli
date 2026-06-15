"""Delivery + butcher pricing constants.

PRD v2 §3 specifies the formula:  Logistika Narxi = Baza Narxi (Start) + (Masofa × Tarif Koeffitsiyenti)

We keep these constants here (not in DB) for v1 — finance can iterate via a release and we don't need an
admin UI for it yet. When we want per-region pricing or seasonal promotions, promote to a `RateCard` model.
All numbers are in so'm (UZS). Distance is in kilometers (rounded to one decimal in the response).
"""
from dataclasses import dataclass
from decimal import Decimal

from apps.orders.models import Order


@dataclass(frozen=True)
class VehicleRate:
    """One row of the rate card. The slug matches Order.VehicleType so the mobile app can persist the
    selected option straight onto the order without a translation step."""
    code: str                            # matches Order.VehicleType values: REFRIGERATOR / CHORVA_TAXI
    base_fee: Decimal                    # so'm — covers vehicle dispatch + first km
    per_km_fee: Decimal                  # so'm/km — the tariff coefficient from the PRD
    # Refrigerator burns extra fuel on its cold-chain compressor, so its coefficient is higher per the PRD.


# ---- v1 rate card (so'm) ----
# Refrigerator base + per-km is intentionally higher than ChorvaTaksi to reflect the compressor's fuel draw
# (PRD §3 explicitly calls this out).
REFRIGERATOR_RATE = VehicleRate(
    code=Order.VehicleType.REFRIGERATOR,
    base_fee=Decimal("60000.00"),                       # 60k so'm dispatch
    per_km_fee=Decimal("3500.00"),                      # 3.5k so'm/km with active cold chain
)

CHORVA_TAXI_RATE = VehicleRate(
    code=Order.VehicleType.CHORVA_TAXI,
    base_fee=Decimal("40000.00"),                       # 40k so'm dispatch
    per_km_fee=Decimal("2500.00"),                      # 2.5k so'm/km open-bed transport
)


# Flat per-order butcher service fee — slaughter + cut + package for one live animal. v1 keeps this
# fixed; a future revision can scale by animal type (small ruminant vs cattle) once we model that.
BUTCHER_SERVICE_FEE = Decimal("200000.00")              # 200k so'm


def compute_vehicle_price(rate: VehicleRate, distance_km: Decimal) -> Decimal:
    """Apply the PRD formula. Distance is clamped to a non-negative number; rounded to 2 decimals."""
    if distance_km < 0:
        distance_km = Decimal("0")
    return (rate.base_fee + rate.per_km_fee * distance_km).quantize(Decimal("0.01"))
