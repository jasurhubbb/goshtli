"""Fast local test settings — in-memory sqlite so DB-backed tests run without a Postgres server.
Used ad hoc via: pytest --ds=config.settings.test_sqlite ...
"""
from .base import *  # noqa: F401,F403

DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": ":memory:"}}
