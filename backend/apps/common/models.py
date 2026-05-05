"""Shared abstract models — anything domain models inherit so we don't duplicate created_at/updated_at everywhere."""
from django.db import models


class TimeStampedModel(models.Model):
    """Adds created_at / updated_at to any model that inherits it. Required by the database design spec for all main entities."""
    created_at = models.DateTimeField(auto_now_add=True)  # set once on insert; never changes
    updated_at = models.DateTimeField(auto_now=True)      # refreshed on every save() call

    class Meta:
        abstract = True  # no DB table for this — only its children get tables
        ordering = ("-created_at",)  # newest first by default everywhere
