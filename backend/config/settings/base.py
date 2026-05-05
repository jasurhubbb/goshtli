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
THIRD_PARTY_APPS = ["rest_framework", "rest_framework_simplejwt", "django_filters", "corsheaders", "drf_spectacular"]
LOCAL_APPS = ["apps.common", "apps.accounts", "apps.suppliers", "apps.buyers",
              "apps.listings", "apps.orders", "apps.notifications"]
INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

# CORS middleware must be near the top so preflight responses are handled before auth/CSRF
MIDDLEWARE = ["corsheaders.middleware.CorsMiddleware", "django.middleware.security.SecurityMiddleware",
              "django.contrib.sessions.middleware.SessionMiddleware", "django.middleware.common.CommonMiddleware",
              "django.middleware.csrf.CsrfViewMiddleware", "django.contrib.auth.middleware.AuthenticationMiddleware",
              "django.contrib.messages.middleware.MessageMiddleware", "django.middleware.clickjacking.XFrameOptionsMiddleware"]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# Templates — only needed for Django Admin since the API itself returns JSON
TEMPLATES = [{"BACKEND": "django.template.backends.django.DjangoTemplates", "DIRS": [], "APP_DIRS": True,
              "OPTIONS": {"context_processors": ["django.template.context_processors.request",
                                                 "django.contrib.auth.context_processors.auth",
                                                 "django.contrib.messages.context_processors.messages"]}}]

# PostgreSQL connection pulled from .env — same shape works for local-Docker and production
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
    "REFRESH_TOKEN_LIFETIME": timedelta(days=config("REFRESH_TOKEN_LIFETIME_DAYS", default=7, cast=int)),
    "ROTATE_REFRESH_TOKENS": True, "BLACKLIST_AFTER_ROTATION": False, "AUTH_HEADER_TYPES": ("Bearer",)}
