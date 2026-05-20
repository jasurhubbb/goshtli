"""Project package init.

Importing the Celery app here ensures the `@shared_task` decorators inside apps/<name>/tasks.py register
against the same app instance Django sees at startup. Without this import, calling `.delay()` on a task
silently dispatches into a vacuum (no worker picks it up).
"""
from .celery import app as celery_app

__all__ = ("celery_app",)
