# Environment variable matrix — DEV (Render) vs PROD (EC2)

Single reference for **every service URL and secret** the web UI and backends need.  
**DEV** = Render staging (current). **PROD** = EC2 production (fill when hosts are live).

Related: [PRODUCTION_READINESS](./PRODUCTION_READINESS.md) · [DEPLOYMENT](./DEPLOYMENT.md)

---

## Rules

1. **Same secret name, different values** — never copy DEV secrets into PROD.
2. **Admin secret must match** across utils, payments, tickets, and UI build env.
3. **`REACT_APP_*` are build-time** — change Netlify env → trigger new deploy.
4. **`NODE_ENV=production`** on Render — set `CORS_ORIGINS` on every hardened service.
5. **Service URLs** in backend env are for **server-to-server** calls (no browser CORS).

---

## Secret alignment (critical)

| Purpose | Utils | Payments | Tickets | UI (Netlify) |
|---------|-------|----------|---------|--------------|
| Admin / internal API | `ADMIN_PUSH_SECRET` | `INTERNAL_NOTIFY_SECRET` | `ADMIN_TICKET_SECRET` | `REACT_APP_ADMIN_PUSH_SECRET` |

All four must be **identical per environment** (DEV has one value; PROD has a different one).

Generate: `openssl rand -hex 32`

---

## Web UI (Netlify) — build-time `REACT_APP_*`

| Variable | DEV (Render backends) | PROD (EC2) |
|----------|----------------------|------------|
| `REACT_APP_ENV` | `qa` or `local` | `prod` |
| `REACT_APP_PAYMENTS_URL` | `https://payments-j5id.onrender.com` | `https://<prod-payments-host>` |
| `REACT_APP_SOCKET_URL` | same as payments | same as payments |
| `REACT_APP_PROVIDER_URL` | `https://providers-08ug.onrender.com` | prod providers URL |
| `REACT_APP_URL` | same as providers (legacy alias) | same |
| `REACT_APP_UTILS_URL` | `https://utils-jo6c.onrender.com` | prod utils URL |
| `REACT_APP_UTLIS_URL` | optional typo alias → same as utils | optional |
| `REACT_APP_PREFERENCES_URL` | `https://preferences.onrender.com` | prod preferences |
| `REACT_APP_COUPONS_URL` | `https://coupons-o26r.onrender.com` | prod coupons |
| `REACT_APP_REVIEWS_URL` | `https://reviews-19oo.onrender.com` | prod reviews |
| `REACT_APP_TICKETS_URL` | `https://<tickets>.onrender.com` | prod tickets |
| `REACT_APP_CHAT_URL` | `https://chat-b3wl.onrender.com` | prod chat |
| `REACT_APP_ADMIN_PUSH_SECRET` | = utils `ADMIN_PUSH_SECRET` | prod-only secret |
| `REACT_APP_ADMIN_SESSION_MINUTES` | `480` (optional) | `480` |
| Auth0 (`REACT_APP_AUTH0_*`) | Dev Auth0 application | Prod Auth0 application |

**Not used:** `REACT_APP_API_URL` — the UI calls each microservice directly.

---

## Shared backend (all hardened Node services)

| Variable | DEV | PROD | Services |
|----------|-----|------|----------|
| `NODE_ENV` | `production` | `production` | all on Render/EC2 |
| `CORS_ORIGINS` | `http://localhost:3000,https://servease-innovation.netlify.app` | prod web domain only | payments, providers, utils, coupons, preferences, reviews, chat, imageUploader |
| `SOCKET_IO_ORIGINS` | optional; defaults to `CORS_ORIGINS` | optional | payments, chat |

### Postgres TLS (coupons + providers — Sequelize / Prisma)

Bundled AWS RDS CA: `certs/rds-global-bundle.pem` in each service repo. **No new GitHub secret.**

| Variable | DEV (Render) | PROD (EC2 / RDS) |
|----------|--------------|------------------|
| `POSTGRES_SSL_REJECT_UNAUTHORIZED` | omit or `false` (encrypt-only; self-signed / non-RDS hosts) | `true` when Postgres is **AWS RDS/Aurora** |
| `POSTGRES_SSL_CA_PATH` | optional override | `certs/rds-global-bundle.pem` on RDS |
| `POSTGRES_SSL_MODE` | `disable` only for local laptop dev | `verify` optional alias for strict mode |

Default prod behavior is **encrypt-only** unless `POSTGRES_SSL_REJECT_UNAUTHORIZED=true`. DEV Render DB at a raw IP with a self-signed cert should **not** enable strict mode.

---

## Utils

| Variable | DEV | PROD |
|----------|-----|------|
| `PORT` | Render assigns (~3030) | `3030` |
| `ADMIN_PUSH_SECRET` | strong random | **new** prod secret |
| `DATABASE_URL` / `POSTGRES_*` | dev `serveaso1` | prod `serveaso1` |
| `MONGO_URI` | dev Mongo/DocumentDB | prod |
| `AUTH0_DOMAIN` | tenant | same tenant |
| `AUTH0_MANAGEMENT_CLIENT_ID` | M2M app | same |
| `AUTH0_MANAGEMENT_CLIENT_SECRET` | M2M secret | rotate if leaked |
| `AUTH0_AUDIENCE` | API identifier | same |
| `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` | test keys | **live** keys |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | dev Firebase | prod Firebase |
| `PAYMENTS_SERVICE_URL` | `https://payments-j5id.onrender.com` | prod |
| `PROVIDERS_SERVICE_URL` | `https://providers-08ug.onrender.com` | prod |
| `COUPONS_SERVICE_URL` | `https://coupons-o26r.onrender.com` | prod |
| `PREFERENCES_SERVICE_URL` | `https://preferences.onrender.com` | prod |
| `REVIEWS_SERVICE_URL` | `https://reviews-19oo.onrender.com` | prod |

**Admin-only routes** (`/api/platform-status`, PUT platform-settings): header `X-Admin-Push-Secret` = `ADMIN_PUSH_SECRET`.

**Public routes:** `/health`, `/ready`, `/api/platform-settings/public`, `/customer/check-email`.

---

## Payments

| Variable | DEV | PROD |
|----------|-----|------|
| `INTERNAL_NOTIFY_SECRET` | = utils `ADMIN_PUSH_SECRET` | prod secret (same as utils) |
| `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` | **test** (`rzp_test_…`) | **live** (`rzp_live_…`) |
| `RAZORPAY_WEBHOOK_SECRET` | test webhook signing secret | live webhook secret |
| `DATABASE_URL` / `POSTGRES_*` | dev `serveaso1` | prod |
| `UTILS_SERVICE_URL` | `https://utils-jo6c.onrender.com` | prod utils |
| `COUPONS_SERVICE_URL` | `https://coupons-o26r.onrender.com` | prod |
| `MONGO_URI` | dev Mongo | prod |
| `AUTH0_DOMAIN` | tenant | same |
| `AUTH0_AUDIENCE` | API audience | same |
| `JWT_PROTECT_MUTATIONS` | `true` (or `false` while testing) | `true` |
| `OVERDUE_START_REMINDER_ENABLED` | `true` | `true` |

**Never in prod:** `SKIP_RAZORPAY_WEBHOOK_VERIFY`, `SKIP_RAZORPAY_VERIFY`

**Webhook URL:** `https://<payments-host>/api/v2/createEngagements/webhook`

---

## Providers

| Variable | DEV | PROD |
|----------|-----|------|
| `DATABASE_URL` / `POSTGRES_*` | dev `serveaso1` | prod |
| `AUTH0_DOMAIN` | tenant | same |
| `AUTH0_AUDIENCE` | API audience | same |
| `JWT_PROTECT_MUTATIONS` | `true` | `true` |

---

## Coupons

| Variable | DEV | PROD |
|----------|-----|------|
| `DATABASE_URL` / `POSTGRES_*` | dev `serveaso1` | prod |
| `APP_URL` | `https://coupons-o26r.onrender.com` | prod coupons URL |

---

## Preferences

| Variable | DEV | PROD |
|----------|-----|------|
| `MONGO_URI` | dev Mongo | prod |
| `DB_NAME` | `serveaso` | `serveaso` |
| `PORT` | `3001` | `3001` |

---

## Reviews

| Variable | DEV | PROD |
|----------|-----|------|
| `DATABASE_URL` / `POSTGRES_*` | dev DB | prod DB |
| `PORT` | `5005` | `5005` |

---

## Tickets

| Variable | DEV | PROD |
|----------|-----|------|
| `DATABASE_URL` / `POSTGRES_*` | dev `serveaso1` | prod |
| `PAYMENTS_SERVICE_URL` | `https://payments-j5id.onrender.com` | prod payments |
| `ADMIN_TICKET_SECRET` | = utils `ADMIN_PUSH_SECRET` | prod secret |
| `INTERNAL_NOTIFY_SECRET` | same as admin secret | same |
| `TICKET_DEFAULT_SLA_HOURS` | `48` | `48` |

---

## Chat

| Variable | DEV | PROD |
|----------|-----|------|
| `MONGO_URI` | dev Mongo | prod |
| `PORT` | `5000` | `5000` |

---

## Image uploader

| Variable | DEV | PROD |
|----------|-----|------|
| `MONGO_URI` or `MONGODB_URI` | dev Mongo (required) | prod |
| `CLOUDINARY_CLOUD_NAME` / `API_KEY` / `API_SECRET` | dev Cloudinary | prod |
| `CORS_ORIGINS` | Netlify + localhost | prod domain |
| Start command on Render | `npm start` | `npm start` |

---

## GitHub Actions (CI/CD secrets)

| Secret | When |
|--------|------|
| `DEV_DATABASE_URL` | Migrate workflow → dev |
| `PROD_DATABASE_URL` | Migrate workflow → prod |
| `RENDER_DEPLOY_HOOK_*` | Deploy Backend → dev |
| `RENDER_SERVICE_ID_*` | Optional; derived from hook URL in latest workflow |
| `RENDER_API_KEY` | Wait for Render deploy + logs |
| `GH_PAT` | Push submodules before Render deploy |
| `PROD_ENV_*` | Full `.env` body per service for EC2 prod deploy |
| `DEPLOY_NOTIFY_EMAILS` | Comma-separated — deployment summary email recipients |
| `SENDGRID_API_KEY` | SendGrid API key for deploy notification emails |
| `DEPLOY_NOTIFY_FROM` | *(optional)* Verified sender in SendGrid |

---

## DEV verification checklist

- [ ] All `REACT_APP_*` URLs point at current Render hosts (especially `REACT_APP_UTILS_URL`)
- [ ] `REACT_APP_ADMIN_PUSH_SECRET` = utils `ADMIN_PUSH_SECRET`
- [ ] payments `INTERNAL_NOTIFY_SECRET` = same value
- [ ] `CORS_ORIGINS` set on all deployed backend services
- [ ] `curl /health` returns 200 on each service
- [ ] Admin dashboard: Settings → platform-status works (not bare browser URL)
- [ ] Booking smoke: register → quote → pay → provider accept

---

## PROD go-live checklist

- [ ] `npm run db:migrate` on prod through **097**
- [ ] New prod-only admin secret (all four places)
- [ ] Live Razorpay + webhook on prod payments URL
- [ ] `CORS_ORIGINS` = production domain only
- [ ] EC2 `PROD_ENV_*` secrets populated
- [ ] End-to-end smoke on prod-like environment

---

*Last updated: 2026-06-07 — ENV-1. Adjust Render hostnames when services are renamed or moved.*
