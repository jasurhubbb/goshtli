"""Local dev overrides — debug on, permissive CORS, browsable API for Postman-free testing."""
from .base import *  # noqa: F401,F403
from decouple import config, Csv

DEBUG = True
ALLOWED_HOSTS = ["*"]  # safe in dev only; production.py tightens this

# Allow the Flutter app + any localhost origin to call the API during development
CORS_ALLOWED_ORIGINS = config("CORS_ALLOWED_ORIGINS",
                              default="http://localhost:3000,http://localhost:8080", cast=Csv())
CORS_ALLOW_CREDENTIALS = True

# Re-enable the browsable API renderer in dev so we can poke endpoints from a browser without Postman
REST_FRAMEWORK["DEFAULT_RENDERER_CLASSES"] = (  # noqa: F405
    "rest_framework.renderers.JSONRenderer", "rest_framework.renderers.BrowsableAPIRenderer")
