"""Cross-role partner endpoints. Every view checks role internally so the URL set is identical for
SUPPLIER and QASSOB. The mobile app only knows /partner/<path>; the backend routes by request.user.role.

Endpoints implemented here (mounted at /api/v1/partner/):
  GET  /inbox/                   — order/job inbox, role-routed
  POST /orders/<id>/accept/      — accept an order (SUPPLIER) or claim a job (QASSOB)
  POST /orders/<id>/reject/      — reject with reason
  POST /orders/<id>/status/      — advance status via services.transition_order_status
  GET  /earnings/?period=        — F3 earnings aggregates
  GET  /dashboard/               — F-bundle KPI tiles for the Bosh sahifa
  GET  /qassob/calendar/?from=&to=  — F8 capacity day grid
  GET  /reviews/incoming/        — F6 ratings inbox
  POST /reviews/<id>/reply/      — F6 reply
  GET  /loyalty/?top=10          — F11 repeat-buyers
  GET  /smart-tips/              — F12 holiday/seasonality nudges
"""
from datetime import date, datetime, timedelta
from decimal import Decimal

from django.db.models import Avg, Count, Q, Sum
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsPartner, IsQassob
from apps.orders.models import Order
from apps.orders.services import (CancellationNotAllowed, InvalidStatusTransition,
                                    transition_order_status)
from apps.listings.models import Listing


# ----------------------- Inbox -----------------------

class InboxView(APIView):
    """GET /partner/inbox/ — role-routed list of orders the caller can act on.

    SUPPLIER: orders on their listings that are NEW (PENDING), ACTIVE (CONFIRMED/PROCESSING/IN_TRANSIT)
              or DONE (DELIVERED, CANCELLED). Front-end shows three tabs.
    QASSOB: orders matching their `animals_supported` and currently in AWAITING_QASSOB (open offers),
            plus orders assigned to them (their workload).

    Returns a compact list shape — the dedicated /orders/<id>/ endpoint serves the full detail when the
    partner taps a row.
    """
    permission_classes = (IsPartner,)

    def get(self, request):
        u = request.user
        bucket = request.query_params.get("bucket", "new")
        if u.is_supplier:
            base = Order.objects.filter(listing__supplier=u)
            if bucket == "new":
                qs = base.filter(status=Order.Status.PENDING)
            elif bucket == "active":
                # DELIVERED_PENDING_CONFIRMATION stays in ACTIVE so the supplier can watch an order through
                # to the buyer's confirmation (courier marked it delivered; buyer hasn't tapped confirm yet).
                qs = base.filter(status__in=(Order.Status.CONFIRMED, Order.Status.PROCESSING,
                                              Order.Status.PROCESSING_BUTCHER, Order.Status.AWAITING_QASSOB,
                                              Order.Status.IN_TRANSIT,
                                              Order.Status.DELIVERED_PENDING_CONFIRMATION))
            else:
                qs = base.filter(status__in=(Order.Status.DELIVERED, Order.Status.CANCELLED))
        elif u.is_qassob:
            profile = getattr(u, "qassob_profile", None)
            animals = profile.animals_supported if profile else []
            if bucket == "new":
                # Offers waiting for any qassob to claim — match by animal support so qassobs only see
                # jobs they can handle.
                qs = Order.objects.filter(status=Order.Status.AWAITING_QASSOB)
                if animals:
                    # JSON array containment — filter to orders for a Listing whose animal_form indicates
                    # live (since butcher service only applies to live animals).
                    qs = qs.filter(listing__is_live_animal=True)
            elif bucket == "active":
                qs = Order.objects.filter(assigned_qassob=u,
                                            status__in=(Order.Status.PROCESSING_BUTCHER,
                                                         Order.Status.IN_TRANSIT))
            else:
                qs = Order.objects.filter(assigned_qassob=u,
                                            status__in=(Order.Status.DELIVERED, Order.Status.CANCELLED))
        else:
            qs = Order.objects.none()
        qs = (qs.select_related("buyer", "listing", "listing__market",
                                "delivery", "delivery__courier", "delivery__courier__courier_profile")
                .order_by("-created_at")[:50])
        data = [{
            "id": o.id, "status": o.status, "payment_status": o.payment_status,
            "buyer_name": o.buyer.full_name or o.buyer.email,
            "buyer_phone": o.buyer.phone or "",
            "listing_id": o.listing_id, "listing_name": o.listing.name_uz,
            "quantity_kg": str(o.quantity_kg), "total_price": str(o.total_price),
            "delivery_address": o.delivery_address,
            "butcher_service": o.butcher_service_requested,
            "is_live_animal": o.listing.is_live_animal,
            "created_at": o.created_at.isoformat(),
            # v3.9.16 — who's delivering, so the supplier UI shows "courier is delivering" + a contact card
            # once the order is dispatched (null before IN_TRANSIT).
            "courier": _courier_info(o),
        } for o in qs]
        return Response({"bucket": bucket, "count": len(data), "results": data})


def _courier_info(order):
    """Delivery/courier summary for the supplier inbox once an order is dispatched (IN_TRANSIT onward).
    None before dispatch. `mode`:
      • 'self'    — the supplier is delivering it themselves (listing.supplier_delivers)
      • 'courier' — a platform courier is delivering it (name/phone/vehicle/rating included)
      • 'pending' — dispatched but no real courier assigned yet (ops will reassign the fallback stub)
    """
    delivery = getattr(order, "delivery", None)
    if delivery is None:
        return None
    c = delivery.courier
    if c is not None and c.id == order.listing.supplier_id:
        return {"mode": "self", "name": c.full_name or "Yetkazib beruvchi", "phone": c.phone or "",
                "delivery_status": delivery.status}
    if c is not None and c.is_courier:
        cp = getattr(c, "courier_profile", None)
        return {"mode": "courier",
                "name": (cp.full_name if cp and cp.full_name else "") or c.full_name or "Kuryer",
                "phone": c.phone or "",
                "vehicle_kind": getattr(cp, "vehicle_kind", "") if cp else "",
                "vehicle_plate": getattr(cp, "vehicle_plate", "") if cp else "",
                "rating_avg": float(cp.rating_avg) if cp and cp.rating_count else 0.0,
                "rating_count": cp.rating_count if cp else 0,
                "delivery_status": delivery.status}
    return {"mode": "pending"}


# ----------------------- Accept / Reject / Advance -----------------------

class _RejectSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=300, required=False, allow_blank=True, default="")


class _StatusSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Order.Status.choices)


class AcceptOrderView(APIView):
    """POST /partner/orders/<id>/accept/ — F2 one-tap accept.

    SUPPLIER: PENDING → CONFIRMED on their own listing.
    QASSOB: claims an AWAITING_QASSOB order; sets assigned_qassob + qassob_payout, transitions to
            PROCESSING_BUTCHER. Race-safe: select_for_update on the order row.
    """
    permission_classes = (IsPartner,)

    def post(self, request, order_id: int):
        u = request.user
        try:
            if u.is_supplier:
                # Use the existing service-layer transition (it checks listing ownership).
                order = transition_order_status(order_id=order_id, new_status=Order.Status.CONFIRMED, by_user=u)
            elif u.is_qassob:
                # Atomic claim — first qassob to tap Accept wins; later ones get a 409.
                from django.db import transaction
                with transaction.atomic():
                    order = Order.objects.select_for_update().get(pk=order_id)
                    if order.status != Order.Status.AWAITING_QASSOB:
                        return Response({"detail": f"Order is {order.status}, not AWAITING_QASSOB."},
                                          status=status.HTTP_409_CONFLICT)
                    if order.assigned_qassob_id is not None:
                        return Response({"detail": "Already claimed."}, status=status.HTTP_409_CONFLICT)
                    order.assigned_qassob = u
                    # Snapshot payout — 60% of the butcher_service_fee. Adjust by config later.
                    order.qassob_payout = (order.butcher_service_fee * Decimal("0.60")).quantize(Decimal("0.01"))
                    order.status = Order.Status.PROCESSING_BUTCHER
                    order.save(update_fields=["assigned_qassob", "qassob_payout", "status", "updated_at"])
            else:
                return Response({"detail": "Role not allowed."}, status=status.HTTP_403_FORBIDDEN)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)
        except InvalidStatusTransition as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"id": order.id, "status": order.status})


class RejectOrderView(APIView):
    """POST /partner/orders/<id>/reject/ — refuses the order.

    SUPPLIER: PENDING → CANCELLED on own listing (restores stock via cancel_order).
    QASSOB: leaves the offer in pool for the next qassob (does NOT cancel the order). We just log the
            rejection on the side via notes so the dispatch system can deprioritise the same qassob next
            time. For v1 this is a no-op on the order; client gets 200 and the offer disappears from
            that qassob's inbox (we'd need a "rejected_by" tracker to do that properly — phase 2).
    """
    permission_classes = (IsPartner,)

    def post(self, request, order_id: int):
        s = _RejectSerializer(data=request.data); s.is_valid(raise_exception=True)
        u = request.user
        try:
            order = Order.objects.select_related("listing").get(pk=order_id)
        except Order.DoesNotExist:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        if u.is_supplier:
            if order.listing.supplier_id != u.id:
                return Response({"detail": "Not your order."}, status=status.HTTP_403_FORBIDDEN)
            try:
                from apps.orders.services import cancel_order
                cancel_order(order_id=order.id, by_user=u)
                return Response({"id": order.id, "status": Order.Status.CANCELLED})
            except CancellationNotAllowed as e:
                return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        if u.is_qassob:
            # Phase 2: track per-qassob rejection. For now, just ack.
            return Response({"id": order.id, "skipped": True})
        return Response({"detail": "Role not allowed."}, status=status.HTTP_403_FORBIDDEN)


class AdvanceStatusView(APIView):
    """POST /partner/orders/<id>/status/ — advance forward via the existing state machine."""
    permission_classes = (IsPartner,)

    def post(self, request, order_id: int):
        s = _StatusSerializer(data=request.data); s.is_valid(raise_exception=True)
        try:
            order = transition_order_status(order_id=order_id, new_status=s.validated_data["status"],
                                             by_user=request.user)
        except Order.DoesNotExist:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        except InvalidStatusTransition as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"id": order.id, "status": order.status})


# ----------------------- Earnings (F3) -----------------------

def _period_window(period: str):
    """Returns (since, until) for the requested period. Defaults to 'day' (last 24h)."""
    now = timezone.now()
    if period == "week": return now - timedelta(days=7), now
    if period == "month": return now - timedelta(days=30), now
    return now - timedelta(hours=24), now


def _partner_orders_qs(user, since=None, until=None):
    """Order queryset filtered to this partner's footprint."""
    if user.is_supplier:
        qs = Order.objects.filter(listing__supplier=user)
    elif user.is_qassob:
        qs = Order.objects.filter(assigned_qassob=user)
    else:
        qs = Order.objects.none()
    if since: qs = qs.filter(created_at__gte=since)
    if until: qs = qs.filter(created_at__lte=until)
    return qs


class EarningsView(APIView):
    """GET /partner/earnings/?period=day|week|month — aggregates over partner's orders."""
    permission_classes = (IsPartner,)

    def get(self, request):
        period = request.query_params.get("period", "day")
        since, until = _period_window(period)
        qs = _partner_orders_qs(request.user, since, until).filter(
            payment_status=Order.PaymentStatus.PAID)
        # For QASSOB, earnings = qassob_payout. For SUPPLIER, earnings = total_price (less delivery,
        # less butcher fee). For v1 we surface total_price for simplicity; refine later.
        if request.user.is_qassob:
            total = qs.aggregate(s=Sum("qassob_payout"))["s"] or Decimal("0")
        else:
            total = qs.aggregate(s=Sum("total_price"))["s"] or Decimal("0")
        count = qs.count()
        avg_ticket = (total / count) if count else Decimal("0")
        # Top product (SUPPLIER only) — most-ordered listing by qty in the window
        top_product = None
        if request.user.is_supplier:
            top = (qs.values("listing__name_uz")
                     .annotate(qty=Sum("quantity_kg"))
                     .order_by("-qty").first())
            if top: top_product = top["listing__name_uz"]
        # Daily breakdown for the chart (last N days; N=7 for week, 30 for month, 24 buckets for day=hours)
        chart = self._chart(qs, period, since, until, request.user)
        return Response({
            "period": period,
            "total_revenue": str(total),
            "order_count": count,
            "avg_ticket": str(avg_ticket.quantize(Decimal("0.01")) if avg_ticket else avg_ticket),
            "top_product": top_product,
            "chart": chart,
        })

    def _chart(self, qs, period, since, until, user):
        """Return a list of {label, value} dicts the front-end fl_chart consumes."""
        from collections import defaultdict
        buckets = defaultdict(Decimal)
        for o in qs.values_list("created_at", "total_price", "qassob_payout"):
            ts, tp, qp = o
            local = timezone.localtime(ts)
            key = local.strftime("%H:00") if period == "day" else local.strftime("%Y-%m-%d")
            buckets[key] += (qp if user.is_qassob else tp)
        return [{"label": k, "value": str(v.quantize(Decimal("0.01")))}
                for k, v in sorted(buckets.items())]


# ----------------------- Dashboard KPI bundle -----------------------

class DashboardView(APIView):
    """GET /partner/dashboard/ — KPI tiles for Bosh sahifa.

    Single endpoint so the home screen does ONE network call. Cheap aggregates over the partner's data.
    """
    permission_classes = (IsPartner,)

    def get(self, request):
        u = request.user
        today_since = timezone.now() - timedelta(hours=24)
        today_qs = _partner_orders_qs(u, since=today_since).filter(payment_status=Order.PaymentStatus.PAID)
        if u.is_qassob:
            today_revenue = today_qs.aggregate(s=Sum("qassob_payout"))["s"] or Decimal("0")
        else:
            today_revenue = today_qs.aggregate(s=Sum("total_price"))["s"] or Decimal("0")
        # "Yangi buyurtmalar" KPI — must match the Inbox "Yangi" tab's definition or the supplier sees
        # a count on the dashboard with nothing in the corresponding tab. PENDING only (= orders that
        # still need accept/reject). CONFIRMED + PROCESSING moved to a separate "active" semantic
        # already counted via the Jarayonda tab when needed. v3.8.6 fix.
        if u.is_supplier:
            open_orders = Order.objects.filter(listing__supplier=u,
                                                  status=Order.Status.PENDING).count()
            low_stock = Listing.objects.filter(supplier=u, quantity_kg__lt=20).count()
        else:
            # Qassob: "new" = available offers they could claim. Workload (PROCESSING_BUTCHER) is
            # already in Jadval / Jarayonda, not "new".
            open_orders = Order.objects.filter(status=Order.Status.AWAITING_QASSOB).count()
            low_stock = 0
        # Verification + open/closed snapshot
        if u.is_supplier and hasattr(u, "supplier_profile"):
            is_verified = u.supplier_profile.is_verified
            is_open_now = u.supplier_profile.is_open_now
        elif u.is_qassob and hasattr(u, "qassob_profile"):
            is_verified = u.qassob_profile.is_verified
            is_open_now = u.qassob_profile.is_open_now
        else:
            is_verified = False
            is_open_now = False

        # v3.9 — also surface qassob's daily_capacity_head so the partner-app dashboard can show a
        # "Bugungi sig'im" tile in place of "Kam zaxira" (which doesn't make sense for qassobs).
        daily_capacity = 0
        if u.is_qassob and hasattr(u, "qassob_profile"):
            daily_capacity = u.qassob_profile.daily_capacity_head or 0

        return Response({
            "role": u.role,
            "is_verified": is_verified,
            "is_open_now": is_open_now,
            "today_revenue": str(today_revenue),
            "open_orders": open_orders,
            "low_stock_count": low_stock,
            "daily_capacity_head": daily_capacity,
            "unread_reviews": 0,                              # wired in F6 below; 0 for v1
        })


# ----------------------- Qassob capacity calendar (F8) -----------------------

class QassobCalendarView(APIView):
    """GET /partner/qassob/calendar/?from=YYYY-MM-DD&to=YYYY-MM-DD — daily booked-vs-capacity grid."""
    permission_classes = (IsQassob,)

    def get(self, request):
        try:
            d_from = datetime.strptime(request.query_params["from"], "%Y-%m-%d").date()
            d_to = datetime.strptime(request.query_params["to"], "%Y-%m-%d").date()
        except (KeyError, ValueError):
            today = date.today()
            d_from, d_to = today, today + timedelta(days=14)
        cap = getattr(request.user.qassob_profile, "daily_capacity_head", 10)
        # Count orders assigned to this qassob with delivery_time_slot anchored to the day. For v1 we
        # treat created_at as the slot day; switch to delivery_lat/lng-based scheduling later.
        bucket = {}
        cur = d_from
        while cur <= d_to:
            count = Order.objects.filter(assigned_qassob=request.user,
                                           created_at__date=cur,
                                           status__in=(Order.Status.PROCESSING_BUTCHER,
                                                        Order.Status.IN_TRANSIT,
                                                        Order.Status.DELIVERED)).count()
            bucket[cur.isoformat()] = {"booked": count, "capacity": cap}
            cur += timedelta(days=1)
        return Response({"daily_capacity_head": cap, "days": bucket})


# ----------------------- Reviews inbox + reply (F6) -----------------------

class ReviewsInboxView(APIView):
    """GET /partner/reviews/incoming/ — reviews left for me. Phase-1 returns empty if apps.reviews
    doesn't expose a per-supplier query yet; we still ship the endpoint so the mobile UI is wired."""
    permission_classes = (IsPartner,)

    def get(self, request):
        try:
            from apps.reviews.models import Review
            if request.user.is_supplier:
                qs = Review.objects.filter(supplier=request.user).select_related("buyer").order_by("-created_at")
            else:
                qs = Review.objects.none()
            data = [{
                "id": r.id,
                "rating": r.rating,
                "comment": r.comment,
                "buyer_name": r.buyer.full_name or r.buyer.email,
                "reply_text": getattr(r, "reply_text", "") or "",
                "created_at": r.created_at.isoformat(),
            } for r in qs[:50]]
            return Response({"results": data, "count": len(data)})
        except Exception:
            return Response({"results": [], "count": 0})


class ReviewReplyView(APIView):
    """POST /partner/reviews/<id>/reply/ — F6 reply. Writes `reply_text` on the Review row when the
    apps.reviews schema supports it; otherwise returns 501 so the mobile shows 'Coming soon'."""
    permission_classes = (IsPartner,)

    def post(self, request, review_id: int):
        try:
            from apps.reviews.models import Review
            review = get_object_or_404(Review, pk=review_id)
            if not hasattr(review, "reply_text"):
                return Response({"detail": "Reply feature is being rolled out."}, status=501)
            if review.supplier_id != request.user.id:
                return Response({"detail": "Not your review."}, status=status.HTTP_403_FORBIDDEN)
            review.reply_text = request.data.get("reply_text", "")
            review.save(update_fields=["reply_text"])
            return Response({"id": review.id, "reply_text": review.reply_text})
        except Exception:
            return Response({"detail": "Reviews app not available."}, status=501)


# ----------------------- F11 Loyalty -----------------------

class LoyaltyView(APIView):
    """GET /partner/loyalty/?top=10 — top-N repeat buyers by order count."""
    permission_classes = (IsPartner,)

    def get(self, request):
        try: top = max(1, min(50, int(request.query_params.get("top", "10"))))
        except (TypeError, ValueError): top = 10
        qs = _partner_orders_qs(request.user)
        leaderboard = (qs.values("buyer__id", "buyer__full_name", "buyer__email", "buyer__phone")
                          .annotate(orders=Count("id"), total=Sum("total_price"))
                          .order_by("-orders")[:top])
        return Response({"results": [{
            "buyer_id": r["buyer__id"],
            "buyer_name": r["buyer__full_name"] or r["buyer__email"],
            "phone": r["buyer__phone"] or "",
            "orders": r["orders"],
            "total": str(r["total"]),
        } for r in leaderboard]})


# ----------------------- F12 Smart tips -----------------------

# Hardcoded Uzbek holidays + recurring high-demand windows. Tiny v1 — expand annually.
_UZ_HOLIDAYS = (
    # (month, day, name, why-it-matters-message)
    (3, 21, "Navro'z", "Bayram oldidan buyurtmalar 2x ko'payadi. Zaxirani oshiring."),
    (9, 1, "Mustaqillik kuni", "Mehmondo'stlik mavsumi — ulgurji buyurtmalar oshadi."),
    # Approximate Ramazon Hayit / Qurbon Hayit — varies yearly; admin updates this list.
    (6, 16, "Qurbon Hayit (taxminiy)", "Qurbonlik oldidan tirik chorva talabini kuting."),
)


class SmartTipsView(APIView):
    """GET /partner/smart-tips/ — upcoming holidays + heuristic suggestions for the Bosh sahifa tile."""
    permission_classes = (IsPartner,)

    def get(self, request):
        today = date.today()
        tips = []
        for (m, d, name, msg) in _UZ_HOLIDAYS:
            target = date(today.year, m, d)
            if target < today: target = date(today.year + 1, m, d)
            days = (target - today).days
            if days <= 30:
                tips.append({"days_until": days, "name": name, "message": msg})
        tips.sort(key=lambda t: t["days_until"])
        return Response({"tips": tips})


# ----------------------- F5 Quick-price on Listing -----------------------

class QuickPriceSerializer(serializers.Serializer):
    price_per_kg = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("0.01"))


class QuickPriceView(APIView):
    """POST /listings/<id>/quick-price/ — F5 one-tap price edit on the SUPPLIER's catalog."""
    permission_classes = (IsPartner,)

    def post(self, request, listing_id: int):
        try: listing = Listing.objects.get(pk=listing_id, supplier=request.user)
        except Listing.DoesNotExist:
            return Response({"detail": "Not your listing."}, status=status.HTTP_404_NOT_FOUND)
        s = QuickPriceSerializer(data=request.data); s.is_valid(raise_exception=True)
        listing.price_per_kg = s.validated_data["price_per_kg"]
        listing.save(update_fields=["price_per_kg", "updated_at"])
        return Response({"id": listing.id, "price_per_kg": str(listing.price_per_kg)})


# ----------------------- F1 Supplier availability toggle -----------------------

class SupplierAvailabilityView(APIView):
    """POST /suppliers/me/availability/ — supplier F1 mirror of qassob's availability toggle."""
    permission_classes = (IsPartner,)

    def post(self, request):
        if not request.user.is_supplier:
            return Response({"detail": "Supplier-only."}, status=status.HTTP_403_FORBIDDEN)
        is_open = bool(request.data.get("is_open_now"))
        # Lazy import to avoid a top-level cycle.
        from apps.suppliers.models import SupplierProfile
        SupplierProfile.objects.filter(user=request.user).update(is_open_now=is_open)
        return Response({"is_open_now": is_open})
