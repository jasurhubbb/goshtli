"""Celery app bootstrap — discovered by config/__init__.py at Django startup so workers and producers
share the same configuration.

What runs here:
  • The Celery app is instantiated with the project's Django settings module attached.
  • config_from_object() pulls every CELERY_* setting from base.py (broker URL, serializer, time zone).
  • autodiscover_tasks() walks every INSTALLED_APP for a tasks.py module — drop one in any app and it's wired.

To start a worker locally:
  celery -A config worker -l info

In production, the docker-compose `worker` service runs the same command.
"""
import os

from celery import Celery


# Tell Celery which settings module to load BEFORE instantiating the app — same dance as manage.py.
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")

app = Celery("goshtli")

# Pull every "CELERY_..." setting from Django settings (CELERY_BROKER_URL → app.conf.broker_url, etc.).
# The `namespace="CELERY"` strips the prefix so the keys land at app.conf.<lower>.
app.config_from_object("django.conf:settings", namespace="CELERY")

# Walk INSTALLED_APPS for tasks.py modules. apps.listings.tasks shows up here once it's defined.
app.autodiscover_tasks()
