"""Shared Django settings — common to all environments. Env-specific overrides live in development.py / production.py."""
from pathlib import Path
from datetime import timedelta
from decouple import config, Csv

# BASE_DIR points to the backend/ root so paths like staticfiles/ resolve correctly
BASE_DIR = Path(__file__).resolve().parent.parent.parent

# Secret key + debug come from .env so we never commit secrets; defaults are dev-only
SECRET_KEY = config("SECRET_KEY", default="dev-only-change-in-prod")
DEBUG = config("DEBUG", default=False, cast=bool)
ALLOWED_HOSTS = config("ALLOWED_HOSTS", default="127.0.0.1,localhost", cast=Csv())

# Apps split into Django built-ins, third-party libs, and our own domain apps for readability
DJANGO_APPS = ["django.contrib.admin", "django.contrib.auth", "django.contrib.contenttypes",
               "django.contrib.sessions", "django.contrib.messages", "django.contrib.staticfiles"]
THIRD_PARTY_APPS = ["rest_framework", "rest_framework_simplejwt", "django_filters", "corsheaders", "drf_spectacular",
                    # Row-level audit trail (apps.listings.Listing, apps.markets.Market) — v3.1 catalog overhaul
                    "simple_history",
                    # v3.9 — Channels powers the WebSocket chat consumer. MUST come before staticfiles in
                    # INSTALLED_APPS so its `runserver` override (ASGI-aware) wins; if it's listed after,
                    # plain HTTP `runserver` boots and WebSockets silently 404 in development. Production
                    # runs uvicorn directly so the ordering doesn't matter there, but local dev does.
                    "channels"]
LOCAL_APPS = ["apps.common", "apps.accounts", "apps.suppliers", "apps.buyers",
              "apps.listings", "apps.orders", "apps.notifications",
              # v2 Milestone C — social + trust features
              "apps.favorites", "apps.reviews", "apps.chats",
              # v3.1 catalog overhaul — vendor entity sitting above Listing
              "apps.markets",
              # v3.5 payment provider abstraction (Mock for dev + tester builds, Payme for production)
              "apps.payments",
              # v3.6 PRD §3 — delivery quote endpoint. Pure compute (no models); persistence lives on apps.orders.
              "apps.delivery",
              # v3.8 — Qassob (butcher + slaughterhouse) profile + admin + listing surface. Powers the
              # partners-app Qassob role and the buyer-app Servislar tab.
              "apps.qassobs",
              # v3.8 — Cross-role partner-app endpoints (inbox, earnings, dashboard, calendar, reviews,
              # loyalty, smart-tips). Routes data by role internally so the mobile sees one URL set.
              "apps.partner"]
INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

# CORS middleware must be near the top so preflight responses are handled before auth/CSRF
MIDDLEWARE = ["corsheaders.middleware.CorsMiddleware", "django.middleware.security.SecurityMiddleware",
              # WhiteNoise — serves STATIC_ROOT directly in production where DEBUG=False disables Django's
              # built-in static handler. MUST sit immediately after SecurityMiddleware per its README so the
              # static files are wrapped in security headers but ahead of everything that would do redirects.
              "whitenoise.middleware.WhiteNoiseMiddleware",
              "django.contrib.sessions.middleware.SessionMiddleware", "django.middleware.common.CommonMiddleware",
              "django.middleware.csrf.CsrfViewMiddleware", "django.contrib.auth.middleware.AuthenticationMiddleware",
              "django.contrib.messages.middleware.MessageMiddleware", "django.middleware.clickjacking.XFrameOptionsMiddleware",
              # Captures request.user on the HistoricalRecords rows for Listing/Market — must come AFTER AuthenticationMiddleware
              "simple_history.middleware.HistoryRequestMiddleware"]


STATIC_ROOT = BASE_DIR / "staticfiles"  # collectstatic writes here; whitenoise serves from this path

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# Templates — only needed for Django Admin since the API itself returns JSON
TEMPLATES = [{"BACKEND": "django.template.backends.django.DjangoTemplates", "DIRS": [], "APP_DIRS": True,
              "OPTIONS": {"context_processors": ["django.template.context_processors.request",
                                                 "django.contrib.auth.context_processors.auth",
                                                 "django.contrib.messages.context_processors.messages"]}}]

# PostgreSQL connection — supports two shapes for portability:
#   1. DATABASE_URL=postgresql://user:pass@host:port/dbname  (Railway / Render / Heroku default)
#   2. DB_NAME / DB_USER / DB_PASSWORD / DB_HOST / DB_PORT   (legacy .env split)
# The URL form takes precedence when set so cloud hosts that auto-inject DATABASE_URL just work.
def _db_from_url(url):
    """Tiny inline Postgres URL parser — avoids pulling in dj-database-url as a dep for one function.
    Handles postgresql://user:pass@host:port/dbname?sslmode=require ; returns the dict Django expects."""
    from urllib.parse import urlparse, parse_qs, unquote
    p = urlparse(url)
    options = {}
    qs = parse_qs(p.query)
    # Promote sslmode= to Django's OPTIONS so Railway/Render's TLS-enforced Postgres works without extra config
    if "sslmode" in qs: options["sslmode"] = qs["sslmode"][0]
    return {"ENGINE": "django.db.backends.postgresql",
            "NAME": (p.path or "/").lstrip("/"),
            "USER": unquote(p.username or ""),
            "PASSWORD": unquote(p.password or ""),
            "HOST": p.hostname or "",
            "PORT": str(p.port or ""),
            "OPTIONS": options,
            "CONN_MAX_AGE": 60}                          # short-lived connection pool — fine for low traffic, restarts cleanly

_DATABASE_URL = config("DATABASE_URL", default="")
if _DATABASE_URL:
    DATABASES = {"default": _db_from_url(_DATABASE_URL)}
else:
    DATABASES = {"default": {"ENGINE": "django.db.backends.postgresql",
                             "NAME": config("DB_NAME", default="meat_marketplace"),
                             "USER": config("DB_USER", default="postgres"),
                             "PASSWORD": config("DB_PASSWORD", default="postgres"),
                             "HOST": config("DB_HOST", default="localhost"),
                             "PORT": config("DB_PORT", default="5432")}}

# Custom user model — defined here so Django uses ours instead of django.contrib.auth.User from day one
AUTH_USER_MODEL = "accounts.User"

# Password strength validators — Django's defaults are sensible for B2B users
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 8}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"}]

# i18n + timezone — Asia/Tashkent since the marketplace is regional; switch to UTC if going multi-region
LANGUAGE_CODE = "en-us"
TIME_ZONE = "Asia/Tashkent"
USE_I18N = True
USE_TZ = True

# Static + default PK — BigAutoField avoids running out of IDs and is the modern Django default
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Media (user uploads — listing photos, market logos/covers, category images).
#
# Storage selection is automatic based on env vars:
#   • R2_BUCKET set → use Cloudflare R2 (S3-compatible) via django-storages. Production path.
#   • R2_BUCKET unset → fall back to local filesystem at MEDIA_ROOT. Dev path.
#
# Public URLs:
#   • R2: served from R2_PUBLIC_URL (your public r2.dev hostname or custom CDN domain).
#   • Local dev: served from /media/ by Django's urls.py (only when DEBUG=True).
#
# To enable R2:
#   1. Create an R2 bucket in the Cloudflare dashboard
#   2. Generate an API token (Object Read & Write scope, scoped to the bucket)
#   3. Set env vars in .env (or Railway/Render variables):
#        R2_ACCOUNT_ID=abc123...
#        R2_ACCESS_KEY_ID=...
#        R2_SECRET_ACCESS_KEY=...
#        R2_BUCKET=goshtli-prod
#        R2_PUBLIC_URL=https://pub-xxx.r2.dev   (or your CDN domain)
#   4. Redeploy — every ImageField save lands in R2 automatically.
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

R2_BUCKET = config("R2_BUCKET", default="")
USE_R2 = bool(R2_BUCKET)

if USE_R2:
    # Django 5+ uses STORAGES instead of the deprecated DEFAULT_FILE_STORAGE single-string setting.
    # `default` is for user uploads; staticfiles still uses Django's local backend (CDN-served via WhiteNoise or
    # similar would be a follow-up). The s3 backend is S3-API-compatible and works against R2 with endpoint_url set.
    _R2_ACCOUNT_ID = config("R2_ACCOUNT_ID")
    STORAGES = {
        "default": {
            "BACKEND": "storages.backends.s3.S3Storage",
            "OPTIONS": {
                "bucket_name": R2_BUCKET,
                "endpoint_url": f"https://{_R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
                "access_key": config("R2_ACCESS_KEY_ID"),
                "secret_key": config("R2_SECRET_ACCESS_KEY"),
                "region_name": "auto",            # R2 has no real regions; "auto" is the convention
                "signature_version": "s3v4",       # required by R2; default is s3v4 already but pin it
                "addressing_style": "virtual",     # bucket-as-subdomain — works with R2's endpoint scheme
                "default_acl": None,               # R2 doesn't support per-object ACLs; bucket-level policy controls access
                "querystring_auth": False,         # we serve via R2_PUBLIC_URL, not signed URLs
                "file_overwrite": False,           # never silently overwrite; uploads with the same name get a suffix
                # Long-lived cache header — image assets are immutable (uploaded once, never edited).
                # Mobile + CDN can cache aggressively. Re-uploads get a new filename so cache busting is automatic.
                "object_parameters": {"CacheControl": "public, max-age=31536000, immutable"},
                # Public URL prefix the model layer's `instance.image.url` resolves to. Override per env in .env.
                "custom_domain": config("R2_PUBLIC_URL", default="").replace("https://", "").replace("http://", "") or None,
                "url_protocol": "https:",
            },
        },
        # WhiteNoise's manifest storage: compresses static files at collectstatic-time + serves them
        # with long-cache hashed names. Required when DEBUG=False; without it /static/admin/* 404s.
        "staticfiles": {"BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"},
    }
else:
    # Local dev (no R2) — keep `default` on the filesystem (Django default) and still serve staticfiles
    # via whitenoise so behavior matches production. Avoids "works locally but breaks in prod" surprises.
    STORAGES = {
        "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
        "staticfiles": {"BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"},
    }

# 10MB upload cap — keeps gunicorn workers from being held hostage by an attacker uploading huge files
FILE_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024
DATA_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024

# DRF config — JWT auth, page-based pagination, JSON-only responses for predictable mobile parsing
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ("rest_framework_simplejwt.authentication.JWTAuthentication",),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": ("django_filters.rest_framework.DjangoFilterBackend",
                                "rest_framework.filters.SearchFilter", "rest_framework.filters.OrderingFilter"),
    "DEFAULT_RENDERER_CLASSES": ("rest_framework.renderers.JSONRenderer",),
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema"}  # required by drf-spectacular for OpenAPI 3 generation

# OpenAPI / Swagger metadata — keep minimal; full docs live in /docs/api-plan.md and the rendered Swagger UI
SPECTACULAR_SETTINGS = {
    "TITLE": "Meat Marketplace API",
    "DESCRIPTION": "B2B meat marketplace — auth, listings, orders, dashboards. JWT bearer auth on all non-public endpoints.",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,                  # don't expose the raw schema route under /api/v1/schema unless asked
    "COMPONENT_SPLIT_REQUEST": True,                # separate request/response shapes for clearer Swagger UI
    "SCHEMA_PATH_PREFIX": r"/api/v1",                # group routes under the v1 prefix in the generated spec
    "SWAGGER_UI_SETTINGS": {"persistAuthorization": True},  # keep the bearer token across page reloads while testing
    # Listing.Status and Order.Status are both named "status" — disambiguate the generated component names so schema clients don't collide
    "ENUM_NAME_OVERRIDES": {"ListingStatusEnum": "apps.listings.models.Listing.Status",
                            "OrderStatusEnum": "apps.orders.models.Order.Status"}}

# JWT token lifetimes pulled from .env so we can tune without code changes; rotate refresh tokens for security
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=config("ACCESS_TOKEN_LIFETIME_MINUTES", default=60, cast=int)),
    # Bumped 7d → 30d so a tester who opens the app once a week doesn't get bounced through Firebase OTP
    # on every session. Refresh tokens stay signed-stateless; cost of the longer window is acceptable for
    # a B2B buyer app (every refresh rotates and `BLACKLIST_AFTER_ROTATION=False` doesn't accumulate DB rows).
    "REFRESH_TOKEN_LIFETIME": timedelta(days=config("REFRESH_TOKEN_LIFETIME_DAYS", default=30, cast=int)),
    "ROTATE_REFRESH_TOKENS": True, "BLACKLIST_AFTER_ROTATION": False, "AUTH_HEADER_TYPES": ("Bearer",)}

# ----- Celery (async tasks: image resize, future cache warming + daily reports) -----
#
# Broker: Redis. Workers pull from redis://redis:6379/0 in docker-compose; on bare-metal point at the host's Redis.
# Tasks are picked up by celery worker processes (see docker-compose `worker` service) — Django request threads
# never block on them, so an admin uploading a 10MB phone photo doesn't stall the upload page.
#
# In tests we set CELERY_TASK_ALWAYS_EAGER=True so tasks run inline (no Redis dependency) — see pytest.ini /
# test settings. Production sets it False (default) and routes through Redis.
CELERY_BROKER_URL = config("CELERY_BROKER_URL", default="redis://localhost:6379/0")
CELERY_RESULT_BACKEND = config("CELERY_RESULT_BACKEND", default="redis://localhost:6379/0")
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE = TIME_ZONE
# Keep tasks idempotent + short. The resize task should finish within 30s; if it doesn't, the worker is unhealthy.
CELERY_TASK_SOFT_TIME_LIMIT = 60
CELERY_TASK_TIME_LIMIT = 90
# Eager mode flag — flipped True in test settings so pytest doesn't need a running broker.
CELERY_TASK_ALWAYS_EAGER = config("CELERY_TASK_ALWAYS_EAGER", default=False, cast=bool)
CELERY_TASK_EAGER_PROPAGATES = True  # in eager mode, surface exceptions to the caller instead of swallowing


# ----- v3.9 Django Channels (WebSocket chat) -----
#
# CHANNEL_LAYERS is what lets multiple uvicorn workers / containers broadcast events to each other
# (when worker A receives "new message" on its WS, worker B's connected client also needs to know).
# In production this routes through Redis; in tests/dev without Redis we fall back to the in-memory
# channel layer which works for a single-process runserver.
#
# Redis URL pattern reuses the Celery broker URL (same Redis instance, different logical DB index
# so the channel-layer messages don't collide with Celery queues).
_REDIS_URL = config("REDIS_URL", default="") or CELERY_BROKER_URL
if _REDIS_URL.startswith("redis://"):
    # Use db 2 for channels (0 is celery broker, 1 was sometimes used for celery results).
    _CHANNELS_REDIS = _REDIS_URL.rstrip("/").rsplit("/", 1)[0] + "/2"
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {
                "hosts": [_CHANNELS_REDIS],
                # Lift the default 100-msg channel-buffer to 500 so a bursty supplier/qassob exchange
                # doesn't drop messages under brief Redis hiccups.
                "capacity": 500,
                # Channel-level deadline; if a worker hasn't drained its inbox in 60s the connection
                # gets reset rather than buffering indefinitely.
                "expiry": 60,
            },
        },
    }
else:
    # Local dev / test without Redis — in-memory channel layer. Single-process only; broadcasts work
    # within one runserver but won't cross workers.
    CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}
