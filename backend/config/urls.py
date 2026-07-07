"""Root URL config — keeps each domain on its own /api/v1/<area>/ namespace so apps stay decoupled."""
from django.conf import settings
from django.contrib import admin
from django.urls import path, include, re_path
from django.views.static import serve
from drf_spectacular.views import SpectacularAPIView, SpectacularRedocView, SpectacularSwaggerView

from apps.accounts.kyc import KYCListCreateView

# All API routes are versioned under /api/v1/ so we can ship breaking changes later under /api/v2/
urlpatterns = [
    path("admin/", admin.site.urls),                                # Django Admin — supplier verification, ops

    # OpenAPI / Swagger — schema endpoint feeds the two viewer routes. Keep these mounted at /api/v1/ for consistency.
    path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),                       # raw OpenAPI 3.0 JSON
    path("api/v1/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger"),    # interactive Swagger UI
    path("api/v1/redoc/", SpectacularRedocView.as_view(url_name="schema"), name="redoc"),       # Redoc reading view

    path("api/v1/auth/", include("apps.accounts.urls")),            # register, login, refresh, me, account delete
    path("api/v1/suppliers/", include("apps.suppliers.urls")),      # supplier profile + dashboard
    path("api/v1/buyers/", include("apps.buyers.urls")),            # buyer profile + dashboard
    path("api/v1/listings/", include("apps.listings.urls")),        # listing CRUD + browse + my + photos
    # v3.3 split-out top-level catalog routes — categories list lives in apps.listings.urls.category_urlpatterns,
    # markets is its own small app. Both expose GET to anyone + write to ADMIN role.
    path("api/v1/categories/", include("apps.listings.category_urls")),
    path("api/v1/markets/", include("apps.markets.urls")),
    path("api/v1/orders/", include("apps.orders.urls")),            # order create / cancel / status / list
    # v3.5 — payments app: generate pay link, webhook receiver, sandbox checkout page
    path("api/v1/payments/", include("apps.payments.urls")),
    # v3.6 PRD §3 — delivery quote endpoint (cart -> eligible vehicles + per-km pricing + time slots)
    path("api/v1/delivery/", include("apps.delivery.urls")),
    # v3.8 — Qassob discovery + owner CRUD. Feeds the buyer-app Servislar tab + partners-app Profil.
    path("api/v1/qassobs/", include("apps.qassobs.urls")),
    # v3.8 — KYC document upload + status. Used by both Qassob and Supplier in the partners app.
    path("api/v1/kyc/", KYCListCreateView.as_view(), name="kyc-upload"),
    path("api/v1/kyc/me/", KYCListCreateView.as_view(), name="kyc-mine"),
    # v3.8 — Cross-role partner endpoints (inbox, accept/reject, earnings, dashboard, calendar, reviews,
    # loyalty, smart-tips, quick-price). Mobile sees one URL set; backend routes by role.
    path("api/v1/partner/", include("apps.partner.urls")),
    # v3.9.15 — couriers (delivery drivers). Owner CRUD, queue, delivery-status advance, proof
    # upload, earnings + dashboard aggregates, admin provisioning.
    path("api/v1/couriers/", include("apps.couriers.urls")),
    path("api/v1/notifications/", include("apps.notifications.urls")),  # in-app notifications + unread count

    # v2 Milestone C — social + trust
    path("api/v1/favorites/", include("apps.favorites.urls")),          # GET own, POST/DELETE toggle
    path("api/v1/reviews/", include("apps.reviews.urls")),              # GET list, POST create, GET supplier aggregate
    path("api/v1/chats/", include("apps.chats.urls")),                  # conversations + messages

    # User-uploaded media (listing photos). Django's static-serve view — fine at v2 traffic; replace with a CDN later.
    re_path(r"^media/(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}),
]
