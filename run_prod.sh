#!/usr/bin/env bash
# run_prod.sh — launch the BUYER Flutter app (mobile/) against the PRODUCTION Railway backend.
#
# Same data set the partner app sees when launched via run_partners_prod.sh. Use this to run the
# buyer + partner apps side-by-side on two devices, both talking to prod — perfect for end-to-end
# testing (place an order on the buyer phone, see it land in the partner phone's Buyurtmalar).
#
# Pass a device id as the first arg to skip auto-detect:
#   ./run_prod.sh R59X2005SEW
#
# Running both apps at once:
#   Terminal A:  ./run_partners_prod.sh <partner-device-id>
#   Terminal B:  ./run_prod.sh           <buyer-device-id>
# No backend involvement — both just point at Railway. List your connected devices with:
#   flutter devices
set -euo pipefail

REPO="/Users/newaccount/Documents/myprojects/go-sht-bozori"
BUYER_DIR="$REPO/mobile"

ok()   { printf "\033[32m✓\033[0m %s\n" "$*"; }
info() { printf "\033[36m→\033[0m %s\n" "$*"; }
fail() { printf "\033[31m✗\033[0m %s\n" "$*"; exit 1; }

DEVICE_ID="${1:-}"
if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID=$(cd "$BUYER_DIR" && flutter devices --machine 2>/dev/null \
    | python3 -c 'import sys, json
try: devices = json.load(sys.stdin)
except Exception: sys.exit(0)
for d in devices:
    tp = d.get("targetPlatform", "")
    if tp.startswith("android") or tp.startswith("ios"):
        print(d.get("id", "")); break' || true)
fi
if [ -z "$DEVICE_ID" ]; then
  fail "No Android/iOS device found. Plug in a phone (USB debugging on) or start an emulator, OR pass a device id explicitly: ./run_prod.sh <device-id>"
fi
ok "Device: $DEVICE_ID"

# Quick health check so a bad deploy fails LOUD instead of every API call silently 5xx-ing.
PROD_URL="https://goshtli-production.up.railway.app/api/v1/schema/"
info "Pinging $PROD_URL"
if ! curl -fsS --max-time 5 "$PROD_URL" > /dev/null 2>&1; then
  fail "Production API is not reachable at $PROD_URL. Check Railway dashboard or run_local.sh for local mode."
fi
ok "Production API is up"

# No --dart-define on purpose — env.dart's defaultValue kicks in and points the app at production
# Railway. Same baseline your signed builds use.
echo ""
info "Launching BUYER app on $DEVICE_ID against PRODUCTION"
info "Press 'r' for hot-reload, 'R' for hot-restart, 'q' to quit."
echo ""
cd "$BUYER_DIR"
flutter run -d "$DEVICE_ID"
