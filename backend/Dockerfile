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

# Make /app itself writable by the runtime user — gunicorn 23+ writes a control-server socket at $WORKDIR/.gunicorn.
# WORKDIR creates /app owned by root; --chown on COPY only affects copied files, not the existing directory.
RUN chmod +x /app/entrypoint.sh && chown -R app:app /app

# collectstatic + migrate run at container start (in entrypoint.sh), NOT here — production.py reads ALLOWED_HOSTS via
# decouple.config() at import, and Railway/Render don't inject runtime env vars during the Docker build phase.

USER app
# EXPOSE is informational; real port is whatever $PORT resolves to at runtime (Railway sets dynamically, default 8000)
EXPOSE 8000

# Single entrypoint runs migrations + collectstatic + gunicorn (binding to $PORT). Same container works on Railway,
# Render, Fly, plain `docker run` — no host-specific start-command override needed.
CMD ["/app/entrypoint.sh"]
