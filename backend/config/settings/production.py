"""Production overrides — strict hosts, HTTPS-only cookies, no debug. Loaded when DJANGO_SETTINGS_MODULE=config.settings.production.

Critical settings derived from .env:
  ALLOWED_HOSTS       — fail fast at boot if not set; comma-separated FQDNs
  CORS_ALLOWED_ORIGINS — comma-separated origins; never use "*" here
  SECRET_KEY          — must be a fresh 50-char random string per deploy

Behind a TLS-terminating reverse proxy (Caddy, nginx, Cloudflare), Django needs SECURE_PROXY_SSL_HEADER to recognize HTTPS.
"""
from .base import *  # noqa: F401,F403
from decouple import config, Csv

DEBUG = False
ALLOWED_HOSTS = config("ALLOWED_HOSTS", cast=Csv())                           # required — boot fails if unset
CORS_ALLOWED_ORIGINS = config("CORS_ALLOWED_ORIGINS", cast=Csv(), default="")
CORS_ALLOW_CREDENTIALS = True

# Tell Django to trust the X-Forwarded-Proto header set by the reverse proxy — required for SECURE_SSL_REDIRECT to work behind Caddy/nginx
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
USE_X_FORWARDED_HOST = True

# Hardening — force HTTPS, secure cookies, HSTS, content-type sniffing protection
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
CSRF_TRUSTED_ORIGINS = config("CSRF_TRUSTED_ORIGINS", cast=Csv(),
                              default=",".join(f"https://{h}" for h in ALLOWED_HOSTS) if ALLOWED_HOSTS else "")
SECURE_HSTS_SECONDS = 60 * 60 * 24 * 30                                       # 30d — bump after verifying HTTPS works fully
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "strict-origin-when-cross-origin"
X_FRAME_OPTIONS = "DENY"

# Static files — collected at image-build time into STATIC_ROOT and served by gunicorn via whitenoise-style middleware,
# OR by the reverse proxy directly. Default Django static-files handler works when DEBUG=False if STATIC_ROOT is populated.
STATIC_URL = "/static/"

# Logging — write everything to stdout/stderr so Docker can collect logs. No file rotation needed; the host's log driver handles it.
LOGGING = {
    "version": 1, "disable_existing_loggers": False,
    "formatters": {"simple": {"format": "[{levelname}] {asctime} {name}: {message}", "style": "{"}},
    "handlers": {"console": {"class": "logging.StreamHandler", "formatter": "simple"}},
    "root": {"handlers": ["console"], "level": "INFO"},
    "loggers": {
        "django": {"handlers": ["console"], "level": "INFO", "propagate": False},
        "django.security": {"handlers": ["console"], "level": "WARNING", "propagate": False},
    },
}
