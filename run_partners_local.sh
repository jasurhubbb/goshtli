#!/usr/bin/env bash
# run_partners_local.sh — local dev runner for the PARTNERS Flutter app.
#
# Mirrors run_local.sh (which launches the buyer app) but targets partners_app/. Same backend stack:
#   - Docker Postgres + Redis up
#   - Django runserver on http://<LAN-IP>:8000
#   - Then flutter run on the partners_app project with API_BASE_URL pointing at the Mac's LAN IP
#
# Pass a device id as the first arg if auto-detect picks the wrong one:
#   ./run_partners_local.sh <device-id>
#
# Tip — to run BOTH the buyer + partners apps at the same time:
#   1. Start the backend once via either script (kill it after Django comes up if you like)
#   2. Open two terminals. Terminal A: ./run_local.sh <buyer-device-id>
#                           Terminal B: ./run_partners_local.sh <partner-device-id>
#   The second script will see Postgres already up and Django already listening; it'll just launch
#   Flutter on the second device. Or, kill the backend the first script started and let the second
#   start a fresh one — they both target the same DB.
set -euo pipefail

REPO="/Users/newaccount/Documents/myprojects/go-sht-bozori"
BACKEND_DIR="$REPO/backend"
PARTNERS_DIR="$REPO/partners_app"
BACKEND_LOG="/tmp/goshtli-backend.log"

ok()   { printf "\033[32m✓\033[0m %s\n" "$*"; }
info() { printf "\033[36m→\033[0m %s\n" "$*"; }
fail() { printf "\033[31m✗\033[0m %s\n" "$*"; exit 1; }

# ---------- LAN IP detection ----------
IP=$(ipconfig getifaddr en0 2>/dev/null || true)
[ -z "$IP" ] && IP=$(ipconfig getifaddr en1 2>/dev/null || true)
[ -z "$IP" ] && fail "Could not detect LAN IP — connect to Wi-Fi and retry."
ok "Mac LAN IP: $IP"

# ---------- Device pick (Android/iOS auto-detect, or explicit arg) ----------
DEVICE_ID="${1:-}"
if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID=$(cd "$PARTNERS_DIR" && flutter devices --machine 2>/dev/null \
    | python3 -c 'import sys, json
try: devices = json.load(sys.stdin)
except Exception: sys.exit(0)
for d in devices:
    tp = d.get("targetPlatform", "")
    if tp.startswith("android") or tp.startswith("ios"):
        print(d.get("id", "")); break' || true)
fi
if [ -z "$DEVICE_ID" ]; then
  fail "No Android/iOS device found. Plug in a phone (USB debugging on) or start an emulator, OR pass a device id explicitly: ./run_partners_local.sh <device-id>"
fi
ok "Device: $DEVICE_ID"

# ---------- Docker stack (Postgres + Redis) ----------
if docker ps --format '{{.Names}}' | grep -q '^meat_marketplace_postgres$'; then
  ok "Docker Postgres already up"
else
  info "Starting Docker stack (Postgres + Redis)…"
  (cd "$REPO" && docker compose up -d postgres redis) || fail "docker compose failed — is Docker Desktop running?"
  sleep 2
  ok "Docker stack started"
fi

# ---------- DB existence + password sync ----------
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

# ---------- Backend (Django) ----------
BACKEND_ALREADY_UP=0
if lsof -i :8000 -sTCP:LISTEN >/dev/null 2>&1; then
  # If something is on :8000, assume it's our Django from a parallel run_local.sh and just reuse it.
  # If it's a foreign process, the curl health-check at the end will fail and you'll see it loud.
  info "Port 8000 already in use — reusing existing backend (skip migrate + runserver)"
  BACKEND_ALREADY_UP=1
fi

if [ "$BACKEND_ALREADY_UP" -eq 0 ]; then
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
else
  # Sanity check the in-place backend actually answers schema.
  if ! curl -fsS "http://127.0.0.1:8000/api/v1/schema/" > /dev/null 2>&1; then
    fail "Port 8000 is busy but /api/v1/schema/ doesn't respond. Kill whatever is on :8000 and rerun."
  fi
  ok "Backend on :8000 responding"
fi

# ---------- Partners Flutter app ----------
echo ""
info "Launching PARTNERS app on $DEVICE_ID with API_BASE_URL=http://$IP:8000/api/v1"
info "Press 'r' for hot-reload, 'R' for hot-restart, 'q' to quit."
echo ""
cd "$PARTNERS_DIR"
flutter run -d "$DEVICE_ID" --dart-define=API_BASE_URL="http://$IP:8000/api/v1"
