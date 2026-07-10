#!/usr/bin/env bash
# run_partners_prod.sh — launch the PARTNERS Flutter app against the PRODUCTION Railway backend.
#
# Same behavior your Samsung gets when it opens the signed build: hits
# https://goshtli-production1.up.railway.app/api/v1 (the defaultValue baked into env.dart). No local
# Postgres/Redis/Django needed — your laptop just runs Flutter, the API is hosted.
#
# Use this when you want emulator + physical phone to share the same data set. To go back to a local
# DB for offline / fast-iteration work, use run_partners_local.sh instead.
#
# Pass a device id as the first arg to skip auto-detect:
#   ./run_partners_prod.sh <device-id>
set -euo pipefail

REPO="/Users/newaccount/Documents/myprojects/go-sht-bozori"
PARTNERS_DIR="$REPO/partners_app"

ok()   { printf "\033[32m✓\033[0m %s\n" "$*"; }
info() { printf "\033[36m→\033[0m %s\n" "$*"; }
fail() { printf "\033[31m✗\033[0m %s\n" "$*"; exit 1; }

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
  fail "No Android/iOS device found. Plug in a phone (USB debugging on) or start an emulator, OR pass a device id explicitly: ./run_partners_prod.sh <device-id>"
fi
ok "Device: $DEVICE_ID"

# Quick health check so a bad deploy fails LOUD instead of silently 5xx-ing all calls.
PROD_URL="https://goshtli-production1.up.railway.app/api/v1/schema/"
info "Pinging $PROD_URL"
if ! curl -fsS --max-time 5 "$PROD_URL" > /dev/null 2>&1; then
  fail "Production API is not reachable at $PROD_URL. Check Railway dashboard or run_partners_local.sh for local mode."
fi
ok "Production API is up"

# No --dart-define here on purpose — that's the entire point of this script. env.dart's defaultValue
# kicks in and points the app at production Railway. Same baseline your Samsung uses.
echo ""
info "Launching PARTNERS app on $DEVICE_ID against PRODUCTION"
info "Press 'r' for hot-reload, 'R' for hot-restart, 'q' to quit."
echo ""
cd "$PARTNERS_DIR"
flutter run -d "$DEVICE_ID"
