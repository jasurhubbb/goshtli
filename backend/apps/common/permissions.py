"""Reusable DRF permission classes.

BUYER is the consumer-app role. SUPPLIER remains the wire/database name for the platform's private catalog
operator so existing listing ownership and partner APIs do not need a destructive migration.
"""
from rest_framework.permissions import BasePermission, SAFE_METHODS


# ---------- Role-based gates (request-level) ----------

class IsAdminRole(BasePermission):
    """Allow only authenticated users with role=ADMIN. Most admin work still goes through Django Admin."""
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_admin_role)


class IsSupplier(BasePermission):
    """Private platform catalog operators only (legacy wire role: SUPPLIER)."""
    def has_permission(self, request, view):
        u = request.user
        return bool(u and u.is_authenticated and u.is_catalog_operator)


class IsBuyer(BasePermission):
    """Consumer-app buyer accounts only."""
    def has_permission(self, request, view):
        u = request.user
        return bool(u and u.is_authenticated and u.is_buyer)


class IsVerifiedSupplier(BasePermission):
    """The real seller gate — caller must have a SupplierProfile AND admin must have flipped is_verified=True.
    Used by listing-create + supplier dashboard endpoints. Profile is opt-in (created via /suppliers/me/ POST), so
    a new user with no profile is gated even before verification kicks in.

    v3.3: ADMIN-role users bypass the verification gate entirely — admins curate listings on behalf of any supplier
    from the mobile admin page.
    """
    def has_permission(self, request, view):
        u = request.user
        if not (u and u.is_authenticated): return False
        if u.is_admin_role: return True                                                   # admin override
        return (u.is_catalog_operator and hasattr(u, "supplier_profile")
                and u.supplier_profile.is_verified)


# ---------- Object-level ownership gates ----------

class IsListingOwnerOrReadOnly(BasePermission):
    """Anyone can GET; only platform catalog staff or admins can mutate listings.

    The class keeps its legacy name so existing imports remain stable. Ownership is intentionally no longer
    authoritative: historical listings retain their old SUPPLIER foreign keys, but the private catalog operator
    must be able to maintain all of them and unmarked legacy suppliers must not regain write access.
    """
    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS: return True
        u = request.user
        return bool(u.is_authenticated and (u.is_catalog_operator or u.is_admin_role))


class IsOrderBuyer(BasePermission):
    """Object-level — restricts to the buyer who placed the order (used by /orders/my/, cancel)."""
    def has_object_permission(self, request, view, obj): return obj.buyer_id == request.user.id


class IsOrderSupplier(BasePermission):
    """Legacy name for the platform-wide catalog-order operator object gate."""
    def has_object_permission(self, request, view, obj):
        return bool(request.user.is_authenticated and request.user.is_catalog_operator)


# ---------- v3.8 partner-app role gates ----------

class IsQassob(BasePermission):
    """role=QASSOB only. Used by /qassobs/me/* endpoints + qassob-only views in /partner/*."""
    def has_permission(self, request, view):
        u = request.user
        return bool(u and u.is_authenticated and u.is_qassob)


class IsVerifiedQassob(BasePermission):
    """Qassob + admin has flipped QassobProfile.is_verified=True. Required for the qassob to appear on
    the buyer-app Servislar tab and to receive AWAITING_QASSOB job offers."""
    def has_permission(self, request, view):
        u = request.user
        if not (u and u.is_authenticated): return False
        if u.is_admin_role: return True
        return u.is_qassob and hasattr(u, "qassob_profile") and u.qassob_profile.is_verified


class IsPartner(BasePermission):
    """Any partner-app role — SUPPLIER or QASSOB or (v3.9.15) COURIER. Used by /partner/* cross-role
    endpoints (inbox, earnings, dashboard, etc.) where the data is role-routed inside the view."""
    def has_permission(self, request, view):
        u = request.user
        return bool(u and u.is_authenticated and (u.is_partner or u.is_admin_role))


# ---------- v3.9.15 courier gates ----------

class IsCourier(BasePermission):
    """role=COURIER only. Used by every /couriers/* endpoint. Note: a supplier acting as their own
    courier for their supplier_delivers listings is NOT role=COURIER — they get an "implicit courier
    hat" via CourierProfile but keep role=SUPPLIER. Those flows use IsCourierOrSelfDeliveringSupplier
    (below) instead of raw IsCourier."""
    def has_permission(self, request, view):
        u = request.user
        return bool(u and u.is_authenticated and u.is_courier)


class IsCourierOrSelfDeliveringSupplier(BasePermission):
    """The broader gate — either a real COURIER account, OR a SUPPLIER who has a CourierProfile
    (auto-created when they mark supplier_delivers=True on at least one listing). Both surfaces use
    the same courier-side UI + endpoints."""
    def has_permission(self, request, view):
        u = request.user
        if not (u and u.is_authenticated): return False
        if u.is_admin_role: return True
        if u.is_courier: return True
        return u.is_supplier and hasattr(u, "courier_profile")
