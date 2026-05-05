#!/bin/sh
# Startup script for the production container — runs migrations + collectstatic, then hands off to gunicorn.
#
# Lives in the Dockerfile CMD so the same container boots correctly on any host (Railway, Render, Fly, plain Docker).
# $PORT defaults to 8000 for local-Docker, but Railway/Render set it dynamically — gunicorn picks up whichever.

set -e   # any failed step kills the boot, surfaces the error in Deploy Logs

python manage.py migrate --noinput
python manage.py collectstatic --noinput

# exec replaces the shell with gunicorn so signals (SIGTERM on container stop) propagate cleanly
exec gunicorn config.wsgi:application \
  --bind "0.0.0.0:${PORT:-8000}" \
  --workers 3 \
  --timeout 60 \
  --access-logfile - \
  --error-logfile -
