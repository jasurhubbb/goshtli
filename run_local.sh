#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/newaccount/Documents/myprojects/go-sht-bozori"
BACKEND_DIR="$REPO/backend"
MOBILE_DIR="$REPO/mobile"
BACKEND_LOG="/tmp/goshtli-backend.log"

ok()   { printf "\033[32m✓\033[0m %s\n" "$*"; }
info() { printf "\033[36m→\033[0m %s\n" "$*"; }
fail() { printf "\033[31m✗\033[0m %s\n" "$*"; exit 1; }

IP=$(ipconfig getifaddr en0 2>/dev/null || true)
[ -z "$IP" ] && IP=$(ipconfig getifaddr en1 2>/dev/null || true)
[ -z "$IP" ] && fail "Could not detect LAN IP — connect to Wi-Fi and retry."
ok "Mac LAN IP: $IP"

DEVICE_ID="${1:-}"
if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID=$(cd "$MOBILE_DIR" && flutter devices --machine 2>/dev/null \
    | python3 -c 'import sys, json
try: devices = json.load(sys.stdin)
except Exception: sys.exit(0)
for d in devices:
    tp = d.get("targetPlatform", "")
    if tp.startswith("android") or tp.startswith("ios"):
        print(d.get("id", "")); break' || true)
fi
if [ -z "$DEVICE_ID" ]; then
  fail "No Android/iOS device found. Plug in a phone (USB debugging on) or start an emulator, OR pass a device id explicitly: ./run_local.sh <device-id>"
fi
ok "Device: $DEVICE_ID"

if docker ps --format '{{.Names}}' | grep -q '^meat_marketplace_postgres$'; then
  ok "Docker Postgres already up"
else
  info "Starting Docker stack (Postgres + Redis)…"
  (cd "$REPO" && docker compose up -d postgres redis) || fail "docker compose failed"
  sleep 2
  ok "Docker stack started"
fi

DB_NAME=$(grep -E '^DB_NAME=' "$BACKEND_DIR/.env" | head -1 | cut -d= -f2 | tr -d '[:space:]')
DB_NAME="${DB_NAME:-meat_marketplace}"
DB_PASSWORD=$(grep -E '^DB_PASSWORD=' "$BACKEND_DIR/.env" | head -1 | cut -d= -f2 | tr -d '[:space:]')
DB_PASSWORD="${DB_PASSWORD:-postgres}"
if ! docker exec meat_marketplace_postgres \
       psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" 2>/dev/null \
       | grep -q '^1$'; then
  info "Database '$DB_NAME' missing — creating it inside the container…"
  docker exec meat_marketplace_postgres psql -U postgres -d postgres \
    -c "CREATE DATABASE $DB_NAME;" >/dev/null || fail "Could not create database $DB_NAME"
  ok "Database '$DB_NAME' created"
else
  ok "Database '$DB_NAME' exists"
fi
docker exec meat_marketplace_postgres psql -U postgres -d postgres \
  -c "ALTER USER postgres WITH PASSWORD '$DB_PASSWORD';" >/dev/null 2>&1 \
  && ok "Postgres password synced with .env" \
  || fail "Could not sync postgres password — is the container healthy?"

if lsof -i :8000 -sTCP:LISTEN >/dev/null 2>&1; then
  fail "Something is already listening on port 8000. Free it (Ctrl-C the other process) and retry."
fi

cd "$BACKEND_DIR"
source .venv/bin/activate

: > "$BACKEND_LOG"
info "Running migrations…"
if ! python manage.py migrate --noinput >> "$BACKEND_LOG" 2>&1; then
  echo ""
  echo "----- migrate output (last 30 lines of $BACKEND_LOG) -----"
  tail -30 "$BACKEND_LOG"
  fail "Migrations failed. Read the lines above — usually a missing env var or a Postgres connection problem."
fi
ok "Migrations applied"

info "Starting Django on http://$IP:8000 (logs: $BACKEND_LOG)"
: > "$BACKEND_LOG"
python manage.py runserver "0.0.0.0:8000" >> "$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!

cleanup() {
  echo ""
  info "Stopping backend (pid=$BACKEND_PID)…"
  kill "$BACKEND_PID" 2>/dev/null || true
  wait "$BACKEND_PID" 2>/dev/null || true
  ok "Backend stopped"
}
trap cleanup INT TERM EXIT

printf "\033[36m→\033[0m Waiting for backend to come up"
for i in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:8000/api/v1/schema/" > /dev/null 2>&1; then
    printf "  ready ✓\n"
    break
  fi
  printf "."
  sleep 1
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    echo ""
    echo "----- backend log (last 20 lines) -----"
    tail -20 "$BACKEND_LOG"
    fail "Backend exited unexpectedly. See $BACKEND_LOG"
  fi
  if [ "$i" -eq 30 ]; then
    echo ""
    fail "Backend didn't respond on /api/v1/schema/ within 30s. See $BACKEND_LOG"
  fi
done

echo ""
info "Launching app on $DEVICE_ID with API_BASE_URL=http://$IP:8000/api/v1"
info "Press 'r' for hot-reload, 'R' for hot-restart, 'q' to quit."
echo ""
cd "$MOBILE_DIR"
flutter run -d "$DEVICE_ID" --dart-define=API_BASE_URL="http://$IP:8000/api/v1"
