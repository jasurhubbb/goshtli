# Multi-stage build — slim runtime image with no build toolchain. ~150MB final, vs ~600MB single-stage.
#
# Stage 1 ("builder") compiles wheels for psycopg2 etc. against gcc + libpq-dev.
# Stage 2 ("runtime") is python:3.12-slim plus only the libpq runtime + the pre-built wheels.
# Result: faster cold-starts on cloud hosts, smaller surface area for security scans.

# ---------- Stage 1: build wheels ----------
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
# Build wheels into /wheels — copied into the runtime stage to avoid shipping gcc + headers
RUN pip wheel --wheel-dir=/wheels -r requirements.txt


# ---------- Stage 2: runtime ----------
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 \
    DJANGO_SETTINGS_MODULE=config.settings.production
WORKDIR /app

# Only the postgres runtime lib is needed at run-time; no build toolchain
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r app && useradd -r -g app -s /usr/sbin/nologin -d /app app

COPY --from=builder /wheels /wheels
RUN pip install --no-index --find-links=/wheels /wheels/*.whl && rm -rf /wheels

COPY --chown=app:app . /app/

# collectstatic intentionally NOT run at build time — production.py reads ALLOWED_HOSTS via decouple.config() at import,
# but Railway / most container hosts don't inject runtime env vars during the Docker build. Static files are collected
# at container start instead, via the platform's start command (e.g. on Railway: "manage.py migrate && manage.py collectstatic && gunicorn ...").

USER app
EXPOSE 8000

# Gunicorn with sensible defaults for a B2B marketplace — 3 workers (2*CPU+1 for a 1-core dyno), 60s timeout
# Tune --workers via env if running on a larger instance; keep --access-logfile=- so logs flow to docker stdout.
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", \
     "--workers", "3", "--timeout", "60", "--access-logfile", "-", "--error-logfile", "-"]
