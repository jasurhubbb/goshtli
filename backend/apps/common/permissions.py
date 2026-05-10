"""Reusable DRF permission classes — v2 uses capability-based gates (any user can buy/sell; verification + ownership
are the real gates). The legacy IsSupplier/IsBuyer classes still exist for backwards-compat but are functionally
equivalent to IsAuthenticated in the v2 world; new endpoints should prefer IsVerifiedSupplier / object-level checks.
"""
from rest_framework.permissions import BasePermission, SAFE_METHODS


# ---------- Role-based gates (request-level) ----------

class IsAdminRole(BasePermission):
    """Allow only authenticated users with role=ADMIN. Most admin work still goes through Django Admin."""
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_admin_role)


class IsSupplier(BasePermission):
    """v2: any authenticated user can act as a supplier (subject to per-action gates like IsVerifiedSupplier).
    Kept as a thin alias so existing references compile while we migrate them away."""
    def has_permission(self, request, view): return bool(request.user and request.user.is_authenticated)


class IsBuyer(BasePermission):
    """v2: any authenticated user can buy. Same alias treatment as IsSupplier."""
    def has_permission(self, request, view): return bool(request.user and request.user.is_authenticated)


class IsVerifiedSupplier(BasePermission):
    """The real seller gate — caller must have a SupplierProfile AND admin must have flipped is_verified=True.
    Used by listing-create + supplier dashboard endpoints. Profile is opt-in (created via /suppliers/me/ POST), so
    a new user with no profile is gated even before verification kicks in.
    """
    def has_permission(self, request, view):
        u = request.user
        if not (u and u.is_authenticated): return False
        return hasattr(u, "supplier_profile") and u.supplier_profile.is_verified


# ---------- Object-level ownership gates ----------

class IsListingOwnerOrReadOnly(BasePermission):
    """Anyone can GET; only the listing's owner (the user who created it) can mutate it. Combined with auth at the view level."""
    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS: return True
        return obj.supplier_id == request.user.id


class IsOrderBuyer(BasePermission):
    """Object-level — restricts to the buyer who placed the order (used by /orders/my/, cancel)."""
    def has_object_permission(self, request, view, obj): return obj.buyer_id == request.user.id


class IsOrderSupplier(BasePermission):
    """Object-level — restricts to the supplier whose listing the order is for (used by supplier status updates)."""
    def has_object_permission(self, request, view, obj): return obj.listing.supplier_id == request.user.id
