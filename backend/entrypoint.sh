#!/bin/sh
# Startup script for the production container — runs as ROOT initially so it can chown the Railway
# persistent volume (mounted as root-owned by default), then drops to the `app` user via gosu for the
# actual Django + gunicorn run.
#
# Lives in the Dockerfile CMD so the same container boots correctly on any host (Railway, Render, Fly,
# plain Docker). $PORT defaults to 8000 for local-Docker, but Railway/Render set it dynamically —
# gunicorn picks up whichever.

set -e   # any failed step kills the boot, surfaces the error in Deploy Logs

# ---- Volume permission fix-up (root) ------------------------------------------------------------
# Railway persistent volumes mount as root-owned. The runtime user (`app`) needs ownership of every
# path it writes to, including the mounted /app/media (uploads) and /app/staticfiles (collectstatic).
# The dirs already exist in the image (created at build time), but the volume mount shadows them with
# whatever's on the volume, so we re-chown on every boot. Idempotent.
mkdir -p /app/media /app/staticfiles
chown -R app:app /app/media /app/staticfiles

# ---- Drop to the app user for everything else ---------------------------------------------------
# `exec gosu app sh -c '...'` replaces this root shell with a child shell running as `app`, then
# execs gunicorn inside. Signals (SIGTERM on container stop) propagate cleanly through the gosu shim.
exec gosu app sh -c '
  set -e
  python manage.py migrate --noinput
  python manage.py collectstatic --noinput

  # Seed demo accounts + listings on boot. Idempotent — get_or_create skips already-existing rows. Set
  # SEED_DEMO=0 in Railway env to disable once youre ready for real users (or just delete the demo
  # accounts via Django Admin afterward). `|| echo ...` so a bad/incompatible seed run doesnt take the
  # whole deploy down — the real app still boots and you can debug seed_demo separately.
  if [ "${SEED_DEMO:-1}" = "1" ]; then
      python manage.py seed_demo || echo "[entrypoint] seed_demo failed; continuing anyway"
  fi

  # v3.9 — swapped gunicorn (WSGI) for uvicorn (ASGI) so the same process serves HTTP + WebSocket
  # protocols. ProtocolTypeRouter in config/asgi.py dispatches per-protocol; existing DRF views
  # continue to work unchanged. `--workers 2` keeps memory predictable on Railway free tier; lift
  # later if HTTP request throughput becomes the bottleneck (chat is the long-lived workload here
  # and benefits more from event-loop concurrency than from extra processes).
  exec uvicorn config.asgi:application \
    --host 0.0.0.0 --port "${PORT:-8000}" \
    --workers 2 \
    --proxy-headers --forwarded-allow-ips="*" \
    --access-log \
    --log-level info
'
