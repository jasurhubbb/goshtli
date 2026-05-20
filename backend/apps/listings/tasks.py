"""Async Celery tasks for the catalog app.

Currently:
  • resize_listing_photo(photo_id) — runs after every ListingPhoto upload. Workers may attach 10MB+ phone
    photos; this task downsizes to max 2000px on the long edge and converts to WebP (typically 5-10x smaller
    while remaining visually indistinguishable). The same field is overwritten so model/serializer code stays
    unchanged. Idempotent: re-running on an already-optimized photo is a no-op.

To trigger manually (e.g. backfill old uploads):
  from apps.listings.tasks import resize_listing_photo
  for p in ListingPhoto.objects.all(): resize_listing_photo.delay(p.id)
"""
from io import BytesIO
import logging

from celery import shared_task
from django.core.files.base import ContentFile
from PIL import Image, ImageOps

log = logging.getLogger(__name__)


# Tunables — kept as module constants so a future settings.py override is one rename away.
MAX_DIMENSION = 2000   # px on the long edge. Anything bigger gets scaled down preserving aspect ratio.
WEBP_QUALITY = 85      # 0-100. 85 is the sweet spot for photo content; 95+ is overkill, <70 visibly grainy.


@shared_task(name="apps.listings.tasks.resize_listing_photo", bind=True, max_retries=2, default_retry_delay=10)
def resize_listing_photo(self, photo_id: int) -> str:
    """Downsize + WebP-convert a single ListingPhoto. Returns the new filename for logging/observability.

    Skips if the photo row is gone (race with delete) or already optimized (filename ends .webp).
    Retries up to twice on transient failures (e.g. storage hiccup); permanent failures (bad image bytes)
    raise so they show up in Sentry / Celery's failed-tasks dashboard.
    """
    # Imported inside the task to avoid circular imports at startup (apps.listings.signals imports this module)
    from .models import ListingPhoto

    try:
        photo = ListingPhoto.objects.get(pk=photo_id)
    except ListingPhoto.DoesNotExist:
        # Photo was deleted between upload and the worker picking up this task — nothing to do.
        log.info("resize_listing_photo: photo %s gone; skipping", photo_id)
        return "skipped: not-found"

    if not photo.image:
        log.warning("resize_listing_photo: photo %s has no file; skipping", photo_id)
        return "skipped: no-file"

    # Don't re-resize an already-WebP image (idempotency guard). The post_save signal also sets
    # _skip_resize on the instance after this task replaces the file, but checking the extension is a belt-and-braces
    # second line of defense for any path that bypasses the signal.
    if photo.image.name.lower().endswith(".webp"):
        return "skipped: already-webp"

    try:
        # Read the original bytes into memory. ListingPhoto sizes are capped at FILE_UPLOAD_MAX_MEMORY_SIZE (10MB),
        # so this is safe; for larger uploads we'd stream chunk-by-chunk through Pillow's lazy loader instead.
        with photo.image.open("rb") as f:
            original_bytes = f.read()

        with Image.open(BytesIO(original_bytes)) as img:
            # Apply EXIF orientation BEFORE resizing — phone photos arrive sideways otherwise.
            img = ImageOps.exif_transpose(img)
            # Convert to RGB; WebP doesn't natively support some palette modes (P, CMYK) without conversion.
            if img.mode not in ("RGB", "RGBA"):
                img = img.convert("RGB")
            # In-place down-scale preserving aspect ratio. Image.thumbnail() is a no-op if already small enough.
            img.thumbnail((MAX_DIMENSION, MAX_DIMENSION), Image.Resampling.LANCZOS)

            # Encode as WebP into a buffer. method=6 is the slowest/highest-compression encoder setting; worth it
            # since this runs on a worker, not in the request thread.
            out = BytesIO()
            img.save(out, format="WEBP", quality=WEBP_QUALITY, method=6)
            out.seek(0)
            optimized_bytes = out.read()

        # Replace the file. Use the same base name with the extension swapped so storage paths stay predictable.
        base_name = photo.image.name.rsplit("/", 1)[-1].rsplit(".", 1)[0]
        new_filename = f"{base_name}.webp"

        # Delete the original (otherwise R2/local both end up storing two files).
        old_path = photo.image.name
        photo.image.delete(save=False)

        # Save the WebP under the same upload_to path (the ImageField's upload_to callable runs again).
        photo.image.save(new_filename, ContentFile(optimized_bytes), save=False)

        # Persist with _skip_resize sentinel so the post_save signal doesn't re-enqueue this same task.
        photo._skip_resize = True
        photo.save(update_fields=["image", "updated_at"])

        log.info("resized photo %s: %s → %s (%d → %d bytes)",
                 photo_id, old_path, photo.image.name, len(original_bytes), len(optimized_bytes))
        return photo.image.name

    except Exception as exc:
        # Retry with backoff. After max_retries the task fails permanently; Celery surfaces that to Sentry / logs.
        log.exception("resize_listing_photo failed for %s", photo_id)
        raise self.retry(exc=exc)
