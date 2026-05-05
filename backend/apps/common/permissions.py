"""Reusable DRF permission classes — role gates + object-level ownership gates used across listings/orders endpoints."""
from rest_framework.permissions import BasePermission, SAFE_METHODS


# ---------- Role-based gates (request-level) ----------

class IsAdminRole(BasePermission):
    """Allow only authenticated users with role=ADMIN. Most admin work goes through Django Admin, but some APIs need this."""
    def has_permission(self, request, view): return bool(request.user and request.user.is_authenticated and request.user.is_admin_role)


class IsSupplier(BasePermission):
    """Authenticated supplier — used by listing CRUD and supplier-side order endpoints."""
    def has_permission(self, request, view): return bool(request.user and request.user.is_authenticated and request.user.is_supplier)


class IsBuyer(BasePermission):
    """Authenticated buyer — used by order placement and buyer dashboard."""
    def has_permission(self, request, view): return bool(request.user and request.user.is_authenticated and request.user.is_buyer)


class IsVerifiedSupplier(BasePermission):
    """Stricter than IsSupplier — also requires the supplier_profile.is_verified flag set by admin. Required to create listings."""
    def has_permission(self, request, view):
        u = request.user
        if not (u and u.is_authenticated and u.is_supplier): return False
        # hasattr guards against the rare case the profile signal hasn't run yet (e.g. raw fixtures)
        return hasattr(u, "supplier_profile") and u.supplier_profile.is_verified


# ---------- Object-level ownership gates ----------

class IsListingOwnerOrReadOnly(BasePermission):
    """Anyone can GET; only the listing's supplier can mutate it. Combined with IsAuthenticated at the view level."""
    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS: return True
        return obj.supplier_id == request.user.id


class IsOrderBuyer(BasePermission):
    """Object-level — restricts an order endpoint to the buyer who placed it (used for /orders/my/, cancel)."""
    def has_object_permission(self, request, view, obj): return obj.buyer_id == request.user.id


class IsOrderSupplier(BasePermission):
    """Object-level — restricts an order endpoint to the supplier whose listing the order is for (used for status updates)."""
    def has_object_permission(self, request, view, obj): return obj.listing.supplier_id == request.user.id
