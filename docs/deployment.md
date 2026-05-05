# Deployment

This guide covers deploying the Meat Marketplace backend + mobile (web) to production. The setup is intentionally **host-agnostic** — same Docker image works on a VPS, Railway, Render, Fly.io, or any container host.

---

## What ships where

| Artifact | Contents | Where it lives in prod |
|---|---|---|
| `backend/Dockerfile` | Python 3.12 + gunicorn + Django | Container host (VPS / Railway / Render / Fly) |
| `mobile/build/web/` | Static Flutter web bundle | CDN / object storage (Cloudflare Pages / Netlify / S3+CloudFront) |
| Postgres 16 | Database | Managed (recommended) or sidecar container |

---

## Option A — Self-hosted VPS (cheapest, most control)

Works on any Linux box with Docker installed (Hetzner, DigitalOcean, Vultr, etc.).

### One-time setup

```bash
# On the server (Ubuntu 22.04+)
ssh root@your.server

# Install Docker + compose plugin
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin

# Clone the repo
git clone <your-repo-url> /opt/meat-marketplace
cd /opt/meat-marketplace

# Create production .env (copy template + fill in real values)
cp backend/.env.production.example backend/.env
nano backend/.env                                      # set SECRET_KEY, ALLOWED_HOSTS, DB_PASSWORD, CORS

# Generate a fresh SECRET_KEY:
docker run --rm python:3.12-slim python -c \
  "import secrets,string; print(''.join(secrets.choice(string.ascii_letters+string.digits+'!@#$%^&*-_+=') for _ in range(50)))"

# Edit Caddyfile to use your real domain
nano Caddyfile                                          # replace api.yourdomain.com

# Point DNS A-records at the server (api.yourdomain.com → server IP)
# Then start the stack
docker compose -f docker-compose.prod.yml --env-file backend/.env up -d

# First-time superuser (interactive)
docker compose -f docker-compose.prod.yml exec backend python manage.py createsuperuser
```

Caddy automatically requests Let's Encrypt certs the first time the domain resolves to your server.

### Updating

```bash
cd /opt/meat-marketplace
git pull
docker compose -f docker-compose.prod.yml build backend
docker compose -f docker-compose.prod.yml up -d backend          # zero-downtime restart of just the API
```

---

## Option B — Railway / Render / Fly.io (managed)

Each platform has its own dashboard but the recipe is the same.

1. Create a managed Postgres add-on. Note the connection string.
2. Create a service from the repo, root `backend/`, builder = Dockerfile.
3. Set env vars (the platform's secrets UI):
   - `DEBUG=False`
   - `SECRET_KEY=<random-50-chars>`
   - `ALLOWED_HOSTS=<your-host>.up.railway.app` (or whichever host)
   - `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT` from the Postgres add-on
   - `CORS_ALLOWED_ORIGINS=https://app.yourdomain.com`
4. Set the start command (only needed if the platform overrides Dockerfile CMD):
   ```
   python manage.py migrate --noinput && gunicorn config.wsgi:application --bind 0.0.0.0:$PORT --workers 3
   ```
5. Deploy. Migrations run on every container start.

The Flutter web bundle deploys separately:

```bash
cd mobile
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
# Upload build/web to Cloudflare Pages / Netlify / S3
```

---

## Mobile — iOS + Android

Web is the easy path. For real mobile distribution:

| Platform | Steps |
|---|---|
| **Android (Play Store)** | `flutter build appbundle --release` → upload `build/app/outputs/bundle/release/app-release.aab` to Play Console. Need a signing key (one-time `keytool -genkey ...`). |
| **iOS (App Store)** | Open `mobile/ios/Runner.xcworkspace` in Xcode → Product → Archive. Need an Apple Developer Program membership ($99/yr). |
| **TestFlight** | Same as App Store but distribute via TestFlight for beta testers — no app review required for internal testers. |

These require Xcode (iOS) or Android Studio (Android) installed on the build machine. CI builds for these platforms are out of scope for the first deployment.

---

## Pre-deploy checklist

- [ ] `SECRET_KEY` is a fresh 50-char random string (never reuse the dev one)
- [ ] `DEBUG=False` in production `.env`
- [ ] `ALLOWED_HOSTS` matches your real FQDN
- [ ] `CORS_ALLOWED_ORIGINS` includes only the mobile app's web origin
- [ ] DB password is strong (24+ chars, generated, not memorable)
- [ ] HTTPS works end-to-end (`curl -I https://api.yourdomain.com/api/v1/docs/` returns 200)
- [ ] Django Admin is reachable and superuser created
- [ ] Run `docker compose exec backend python manage.py check --deploy` — should report 0 issues
- [ ] Backups: schedule a daily `pg_dump` cron on the host (or use the managed DB's snapshot feature)

---

## Smoke test after deploy

```bash
# Replace api.yourdomain.com with your real FQDN

# 1. API doc viewer reachable
curl -I https://api.yourdomain.com/api/v1/docs/

# 2. Public listings endpoint
curl https://api.yourdomain.com/api/v1/listings/

# 3. Auth round-trip
curl -X POST https://api.yourdomain.com/api/v1/auth/register/ \
  -H 'Content-Type: application/json' \
  -d '{"email":"smoke@test.com","full_name":"Smoke","password":"StrongPass123!","role":"BUYER"}'
```

If all three succeed, the deploy is good.

---

## Operations

| Task | Command |
|---|---|
| Tail logs | `docker compose -f docker-compose.prod.yml logs -f backend` |
| Run a migration | `docker compose -f docker-compose.prod.yml exec backend python manage.py migrate` |
| Open Django shell | `docker compose -f docker-compose.prod.yml exec backend python manage.py shell` |
| Database backup | `docker compose -f docker-compose.prod.yml exec postgres pg_dump -U $DB_USER $DB_NAME > backup.sql` |
| Restore | `cat backup.sql \| docker compose -f docker-compose.prod.yml exec -T postgres psql -U $DB_USER -d $DB_NAME` |
| Verify supplier (admin task) | Use Django Admin at `/admin/` — much friendlier than the shell |
