# DEV complete → PROD week checklist

One-page runbook. Tick boxes as you go.  
**Related:** [PRODUCTION_READINESS](./PRODUCTION_READINESS.md) · [ENV_MATRIX](./ENV_MATRIX.md) · [DEPLOYMENT](./DEPLOYMENT.md)

---

## This week — finish DEV (Render + Netlify)

### A. Database

- [x] **Migrate dev DB** — `18/18` SQL applied (through **098**); Prisma tickets up to date
- [x] Confirm `_serveaso_schema_migrations` includes through **`097_maid_cook_promo99_coupons.sql`**
- [x] Confirm coupon columns from **`096`** exist (`booking_condition`, `nth_booking`)
- [x] **DB-2** — Remove coupons `patchCouponSchema` boot DDL after 096 verified on dev

### B. Render services — env & health

Set on **every** deployed backend (`NODE_ENV=production`):

- [x] `CORS_ORIGINS` = `http://localhost:3000,https://servease-innovation.netlify.app` (adjust if UI host changes)

| Service | `/health` 200 | `/ready` 200 | Critical env |
|---------|---------------|--------------|--------------|
| payments | [x] | [x] | `INTERNAL_NOTIFY_SECRET`, Razorpay **test** keys, `AUTH0_*`, `UTILS_SERVICE_URL` |
| providers | [x] | [x] | `AUTH0_*`, `JWT_PROTECT_MUTATIONS=true` |
| utils | [x] | [x] | `ADMIN_PUSH_SECRET`, `MONGO_URI`, `AUTH0_*` (M2M) |
| coupons | [x] | [x] | `DATABASE_URL` |
| preferences | [x] | [x] | `MONGO_URI`, `DB_NAME=serveaso` |
| reviews | [x] | — | `DATABASE_URL` |
| tickets | [x] | — | `ADMIN_TICKET_SECRET`, `PAYMENTS_SERVICE_URL` |
| chat | [x] | — | `MONGO_URI`, `CORS_ORIGINS` |
| imageUploader | [x] | — | `MONGO_URI`, Cloudinary, start cmd `npm start` |

### C. Secret alignment (DEV — all must match)

Generate once per env: `openssl rand -hex 32`

- [x] utils `ADMIN_PUSH_SECRET` aligned
- [x] payments `INTERNAL_NOTIFY_SECRET` = same as above
- [x] tickets `ADMIN_TICKET_SECRET` = same as above
- [x] Netlify `REACT_APP_ADMIN_PUSH_SECRET` = same as above (UI redeployed)

### D. Netlify UI (build-time — redeploy after changes)

- [x] `REACT_APP_PAYMENTS_URL` → `https://payments-vyqp.onrender.com`
- [x] `REACT_APP_SOCKET_URL` → same as payments
- [x] `REACT_APP_PROVIDER_URL` → `https://providers-k8w7.onrender.com`
- [x] `REACT_APP_UTILS_URL` → `https://utils-jo6c.onrender.com`
- [x] `REACT_APP_PREFERENCES_URL`, `REACT_APP_COUPONS_URL`, `REACT_APP_REVIEWS_URL` (`reviews-7aal`), `REACT_APP_TICKETS_URL` (`tickets-3gc8`), `REACT_APP_CHAT_URL`, `REACT_APP_IMAGE_UPLOADER_URL`
- [x] Auth0 `REACT_APP_AUTH0_*` → dev tenant
- [x] `REACT_APP_ADMIN_PUSH_SECRET` aligned (see C)

### E. DEV smoke test (gate before PROD work)

**E1 — Automated API smoke** (run after each deploy):

```bash
npm run test:integration
# or
./tests/integration/smoke-gate.sh
```

- [x] **2026-06-09** — deploy email: `57 pass`, `0 fail`, `1 skip`; metrics **9/9**; all services **live**
- Covers: all `/health` + `/ready`, `/metrics` 9/9, quote→create engagement, coupons, pricing, reviews, webhook HMAC unit, platform-settings public

**E2 — Manual UI smoke** (Netlify DEV + Render DEV) — **✅ DONE**

UI: **https://servease-innovation.netlify.app**

| Step | Flow | Done |
|------|------|------|
| 1 | Customer register / login (Auth0) | [x] |
| 2 | Browse providers → get quote → create booking | [x] |
| 3 | Razorpay **test** payment; webhook **200** in Razorpay Dashboard | [x] |
| 4 | Provider login → accept booking; notifications / Socket.IO update | [x] |
| 5 | Provider start → OTP → complete (or cancel flow) | [x] |
| 6 | Admin → Settings → platform-status (not bare API URL) | [x] |
| 7 | Optional: coupon, review, ticket | [x] optional |

### F. Code quality on DEV (do now — protects PROD deploy)

- [x] **S10** — coupons + providers Postgres SSL: RDS CA bundle (`certs/rds-global-bundle.pem`); redeploy and verify `/health` + `/ready`
- [x] **S11** — Quick audit: no payment/PII leakage in provider/customer API responses (`responseRedaction.js` on payments + providers)
- [x] **S11b** — GET ownership: `resourceAccess.js` + signed OTP session JWT; set `JWT_PROTECT_READS` + `SESSION_JWT_SECRET` on Render
- [x] **CI-1** — PR workflow: lint + reviews typecheck + secret scan (`.github/workflows/pr-checks.yml`)
- [x] **TEST-1** — Integration tests: `npm run test:integration`; CI on push/daily/post-dev-deploy
- [ ] Deploy notification email (optional): `DEPLOY_NOTIFY_FROM=info@serveaso.com` (domain must match SendGrid auth)

**DEV is done when:** A + B + C + D + **E1** + **E2** are checked.

**Status: ✅ DEV GATE COMPLETE** — ready for prod week (EC2 + DB-1 + Phase 4 observability).

---

## Next week — stand up PROD (EC2)

### Day 1 — Infrastructure & secrets

- [ ] EC2 reachable; `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY` in GitHub secrets
- [ ] Generate **new prod-only** admin secret (do not reuse DEV)
- [ ] Prepare multiline `PROD_ENV_*` per service (see [DEPLOYMENT](./DEPLOYMENT.md) list)
- [ ] `CORS_ORIGINS` = **production web domain only** (no localhost)
- [ ] Live Razorpay keys + webhook secret; webhook URL = `https://<prod-payments>/api/v2/createEngagements/webhook`
- [ ] Prod Auth0 app / audience (or same tenant with prod callback URLs)
- [ ] Prod Mongo / Postgres connection strings documented

### Day 2 — Database

- [ ] **DB-1** — Actions → **Deploy Backend** → `environment: prod`, `run_migrations: true` (through **097**)
- [ ] Verify tables: `engagements`, `service_days`, `in_app_notifications`, `support_tickets`, coupon `096` columns
- [ ] Backup taken before migrate; restore drill noted

### Day 3 — Deploy services

- [ ] Actions → **Deploy Backend** → `environment: prod` → `all` (or service-by-service)
- [ ] Each service: `curl https://<host>/health` → 200
- [ ] PM2/Docker processes stable; `VERSION` file matches build id
- [ ] Prod UI build with prod `REACT_APP_*` URLs + prod admin secret

### Day 4 — Go / no-go smoke test

- [ ] Register → book → **live** pay → provider accept → start → complete
- [ ] Razorpay live webhook delivery confirmed
- [ ] Cancellation policy readable (`GET /api/platform-settings/public`)
- [ ] Overdue reminder scheduler enabled if required (`OVERDUE_START_REMINDER_ENABLED`)
- [ ] FCM / Twilio creds on prod utils if push/SMS needed

### Day 5 — Ops & launch

- [ ] **OPS-2** — Alerting: 5xx, webhook failures, DB `/ready` down
- [ ] Runbook: deploy, rollback (`Rollback Backend` workflow), migrate, on-call contact
- [ ] Rollback tested: note previous `releases/<sha-run>` folder name
- [ ] Go / no-go gate (all below) signed off

---

## Go / no-go gate (PROD traffic)

Do not send customer traffic until **all** checked:

- [ ] S1–S4 security blockers complete (Auth0 M2M, webhook HMAC, admin routes, prod secret validation)
- [ ] Prod DB migrated through **096 / 097**
- [ ] All prod env vars set — no localhost fallbacks
- [ ] CORS + Socket.IO allow **production** origins only
- [ ] Health checks pass on **all** deployed services
- [ ] Full smoke test on prod URLs passed

---

## Quick commands

```bash
# Health check (repeat per service host)
curl -sS -o /dev/null -w "%{http_code}\n" https://<host>/health

# Admin platform status (replace secret + utils host)
curl -sS -H "X-Admin-Push-Secret: <secret>" https://<utils-host>/api/platform-status | jq .

# List prod release versions (SSH)
ls -1t /home/ubuntu/payments/releases
cat /home/ubuntu/payments/VERSION

# Local migrate (dev)
npm run db:install && npm run db:migrate
```

---

## After launch (backlog — not launch blockers)

- [ ] JWT on remaining services (coupons, preferences, tickets, reviews, utils mutations)
- [ ] SEC-1 rate limiting + helmet
- [ ] DB-3 trim coupons Prisma schema
- [ ] TEST-2 full E2E automation
- [ ] DOC-1 customer SLA + incident runbook

---

*Last updated: 2026-06-09 — DEV gate complete (A–F + E1 + E2). Prod week next.*
