"""Delivery quote endpoint — POST /api/v1/delivery/quote/

PRD v2 §3: the buyer's cart determines which transport types are eligible:
  • Cart has ONLY raw meat                       → Refrigerator (cold-chain required)
  • Cart has live animal + butcher requested     → Refrigerator (we'll be moving finished meat back)
  • Cart has live animal + butcher NOT requested → ChorvaTaksi (live transport, open-bed)

The endpoint accepts:
  • buyer's address (lat/lng OR plain text — we accept text for v1 and use the supplier's market lat/lng
    for the "from" coord; later this becomes a geocoded address with full routing)
  • listing_ids[] + (optionally) `butcher_service_requested`
For each eligible vehicle it returns:
  • base_fee, per_km_fee, distance_km, total_price
  • a single-line price-breakdown the mobile app shows in a card

The endpoint does NOT persist anything. The mobile app posts the chosen option into the Order's
delivery_* fields when creating the order.
"""
import math
from decimal import Decimal
from typing import Iterable

from rest_framework import permissions, serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.listings.models import Listing
from apps.orders.models import Order
from .pricing import (BUTCHER_SERVICE_FEE, CHORVA_TAXI_RATE, REFRIGERATOR_RATE,
                      compute_vehicle_price, VehicleRate)


# ---------------- Request shape ----------------

class _LineItem(serializers.Serializer):
    """One cart line. quantity_kg = head count for BY_HEAD live listings; the math is identical."""
    listing = serializers.IntegerField(min_value=1)
    quantity_kg = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("0.01"))


class _QuoteRequestSerializer(serializers.Serializer):
    """Input shape — cart content + the buyer's chosen destination lat/lng + the butcher toggle.

    Why lat/lng and not just an address: we compute great-circle distance from supplier coord →
    buyer coord. Lat/lng is unambiguous; an address would force a geocoder dependency we don't need yet.
    """
    items = _LineItem(many=True)
    buyer_lat = serializers.DecimalField(max_digits=9, decimal_places=6)
    buyer_lng = serializers.DecimalField(max_digits=9, decimal_places=6)
    butcher_service_requested = serializers.BooleanField(required=False, default=False)


# ---------------- Distance + helpers ----------------

def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in km. Earth radius = 6371. Good enough for delivery quoting at our scale —
    if/when we move to road-routing (OSRM / Google Distance Matrix), this becomes the fallback only."""
    r = 6371.0
    lat1, lat2 = math.radians(lat1), math.radians(lat2)
    dlat = lat2 - lat1
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def _option_dict(rate: VehicleRate, distance_km: Decimal, available: bool, reason: str = "") -> dict:
    """One vehicle option in the response. `available=False` means the cart's contents preclude this
    vehicle (e.g. live animal in cart with no butcher service → Refrigerator is unavailable).

    The mobile app uses `available` to grey out the radio card; it keeps showing the unavailable option
    so the buyer can see WHY the only remaining choice is e.g. ChorvaTaksi."""
    price = compute_vehicle_price(rate, distance_km)
    return {
        "code": rate.code,
        "available": available,
        "reason_unavailable": reason,
        "base_fee": str(rate.base_fee),
        "per_km_fee": str(rate.per_km_fee),
        "distance_km": str(distance_km.quantize(Decimal('0.01'))),
        "total_price": str(price),
    }


def _coord_pair_or_market_default(listings: Iterable[Listing]) -> tuple[float, float]:
    """Pick the supplier coord to measure FROM. For v1 we use the FIRST listing's market's region as a
    placeholder for the dispatch origin since Market doesn't carry lat/lng yet (added later). Fallback
    to Tashkent center (41.31, 69.27) so the response is never empty even on partial data."""
    for l in listings:
        # No market lat/lng yet — use Tashkent center per the PRD's MVP. Future: add market.lat/lng and
        # use those. The buyer never sees these numbers; they're only used to score distances.
        return 41.3111, 69.2797
    return 41.3111, 69.2797


# ---------------- View ----------------

class DeliveryQuoteView(APIView):
    """POST /api/v1/delivery/quote/  — compute eligible vehicles + per-vehicle pricing for the cart.

    Public — no auth required. The quote is pure computation: takes listing ids + buyer lat/lng, runs
    the haversine + rate-card formula, returns prices and time slots. No DB writes, no PII. Buyers
    should be able to preview "how much will delivery cost?" before ever logging in or signing up.
    Auth still gates the actual /orders/ POST that uses these numbers.
    """

    permission_classes = (permissions.AllowAny,)
    authentication_classes = ()

    def post(self, request):
        s = _QuoteRequestSerializer(data=request.data); s.is_valid(raise_exception=True)
        d = s.validated_data

        # Fetch listings — used to figure out which vehicle types are eligible and to compute distance.
        listing_ids = [item["listing"] for item in d["items"]]
        # v3.9.16 — one product per order. The buyer app enforces a single-product cart; we reject a quote
        # for more than one distinct listing here too (defense in depth) so the invariant also holds
        # server-side. An Order is structurally one listing already (orders.Order.listing is a single FK).
        if len(set(listing_ids)) > 1:
            return Response({"detail": "Bir vaqtda faqat bitta mahsulot buyurtma qilinadi."},
                            status=status.HTTP_400_BAD_REQUEST)
        listings = list(Listing.objects.filter(pk__in=listing_ids).select_related("market"))
        if not listings:
            return Response({"detail": "No matching listings."}, status=status.HTTP_400_BAD_REQUEST)

        # Distance — supplier coord → buyer coord. Quantize to 2 decimals for the response (1.234 → 1.23).
        sup_lat, sup_lng = _coord_pair_or_market_default(listings)
        distance_km = Decimal(str(round(_haversine_km(sup_lat, sup_lng,
                                                      float(d["buyer_lat"]),
                                                      float(d["buyer_lng"])), 2)))

        # Cart classification — drives which vehicles are eligible per PRD §3.
        has_live = any(l.is_live_animal for l in listings)
        has_raw = any(not l.is_live_animal for l in listings)
        butcher_requested = bool(d["butcher_service_requested"])

        # ChorvaTaksi: ONLY when there's a live animal AND butcher service is NOT requested. (We need open-bed
        # transport for the animal itself; once butchered, we need a refrigerator for the finished meat.)
        chorva_taxi_available = has_live and not butcher_requested
        chorva_taxi_reason = "" if chorva_taxi_available else (
            "Tayyor go'sht uchun muzlatgichli furgon kerak" if not has_live else "Qassob xizmati so'ralganda refrigerator ishlatiladi"
        )

        # Refrigerator: when ANY raw meat is in the cart, OR live animal with butcher (because the animal
        # gets slaughtered at the hub and the finished meat needs cold-chain back to the buyer).
        refrigerator_available = has_raw or (has_live and butcher_requested)
        refrigerator_reason = "" if refrigerator_available else "Tirik chorva uchun ChorvaTaksi ishlatiladi"

        options = [
            _option_dict(REFRIGERATOR_RATE, distance_km, refrigerator_available, refrigerator_reason),
            _option_dict(CHORVA_TAXI_RATE, distance_km, chorva_taxi_available, chorva_taxi_reason),
        ]

        # Time-slot enum is fixed by the PRD; we expose it here so the mobile dropdown doesn't have to
        # duplicate the labels — and so adding a 4th slot later only requires a server change.
        time_slots = [
            {"code": Order.TimeSlot.SLOT_0609, "label": "06:00 – 09:00"},
            {"code": Order.TimeSlot.SLOT_0913, "label": "09:00 – 13:00"},
            {"code": Order.TimeSlot.SLOT_1318, "label": "13:00 – 18:00"},
        ]

        # Butcher service fee — surfaced even when has_live is False so the client can show "N/A" instead
        # of having to guess. The mobile app gates the toggle on has_live itself.
        butcher = {
            "available": has_live,
            "requested": butcher_requested,
            "fee": str(BUTCHER_SERVICE_FEE) if butcher_requested and has_live else "0.00",
            "flat_fee": str(BUTCHER_SERVICE_FEE),                    # always show the rate-card number
        }

        return Response({
            "distance_km": str(distance_km),
            "options": options,
            "time_slots": time_slots,
            "butcher_service": butcher,
            "cart_has_live_animal": has_live,
        })
