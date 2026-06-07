# Production readiness — ServEase / Serveaso

Living checklist for going live. Work through items **in order** (P0 → P3). Mark items `[x]` when complete; leave `[ ]` when not done.

**Related docs:** [README](../README.md) · [DEV_PROD_WEEK_CHECKLIST](./DEV_PROD_WEEK_CHECKLIST.md) · [DEPLOYMENT](./DEPLOYMENT.md) · [DATABASE_MIGRATIONS](./DATABASE_MIGRATIONS.md) · [DATABASE_SCHEMA](./DATABASE_SCHEMA.md) · [ENGAGEMENT_CANONICAL](./ENGAGEMENT_CANONICAL.md)

---

## Progress summary

| Area | Status |
|------|--------|
| Phase 0 — Blockers | 5 / 6 |
| Phase 1 — Secure & stable | 6 / 6 |
| Phase 2 — Quality & observability | 0 / 5 |
| Phase 3 — Polish | 0 / 4 |
| Go / no-go gate | 0 / 6 |

*Update counts above when you check off items below.*

### Completed milestones

| Date | Item | Notes |
|------|------|-------|
| 2026-06-02 | **S1** Auth0 M2M secret | Moved to `AUTH0_*` env in utils; `lib/auth0Management.js`; local `/authO` tested |
| 2026-06-02 | **S2** Razorpay webhook | HMAC on `POST /api/v2/createEngagements/webhook`; Razorpay Dashboard delivery confirmed working |
| 2026-06-02 | **S5** `.env.example` scrub | Removed real cloud IPs/passwords; localhost placeholders only |
| 2026-06-02 | **S4** Prod secret validation | payments + utils fail startup in production if dev defaults or missing Razorpay/internal secrets |
| 2026-06-02 | **S3** Admin route protection | `X-Admin-Push-Secret` on utils destructive routes + platform-settings (PUT); payments `/api/admin/*`; public cancellation read |
| 2026-06-02 | **S6–S7** CORS + Socket.IO | `CORS_ORIGINS` on payments, providers, utils, coupons; Socket.IO uses same list; prod startup fails if unset |
| 2026-06-02 | **OPS-1** Health endpoints | `GET /health` + `GET /ready` on payments, providers, coupons, utils |
| 2026-06-02 | **S8** JWT on mutations | Auth0 JWT on POST/PUT/PATCH/DELETE in payments + providers (public registration/pricing/webhook paths exempt) |
| 2026-06-07 | **S9** Hide debugMessage | providers + coupons omit `debugMessage` / `prismaMeta` when `NODE_ENV=production` |
| 2026-06-07 | **ENV-1** Env matrix | [ENV_MATRIX.md](./ENV_MATRIX.md) — DEV Render vs PROD EC2 URLs and secrets |

**Next:** Work [DEV_PROD_WEEK_CHECKLIST](./DEV_PROD_WEEK_CHECKLIST.md) — redeploy coupons + providers (S10), DEV smoke test + migrations, then PROD EC2 next week.

---

## 1. Architecture decisions (current state)

### Monorepo model

- **Parent repo:** [Serveaso](https://github.com/ServEase-Innovations/Serveaso) pins **git submodules** (one repo per service + UI + DB migrations).
- **No BFF:** React UI and iOS call microservices directly via `REACT_APP_*` / env URLs.
- **Node:** `>=20` (root `package.json`).

### Services & ports (local dev)

| Service | Port | Data store | Real-time |
|---------|------|------------|-----------|
| payments | 4100 | Postgres + Socket.IO | Yes — engagement / in-app events |
| providers | 4000 | Postgres | No |
| coupons | 3002 | Postgres (Prisma) | No |
| preferences | 3001 | MongoDB | No |
| utils | 3030 (+ email 4030) | MongoDB | WebSocket (legacy PG notify) |
| reviews | 5005 | Postgres (often separate DB) | No |
| tickets | 5006 | Postgres (shared `serveaso`) | No |
| chat, notifications | optional | varies | optional |

### Cross-service calls

- **payments → utils:** platform settings (cancellation, reminders), optional FCM push (`UTILS_SERVICE_URL`).
- **payments → coupons:** quote / apply / release (`COUPONS_SERVICE_URL`).
- **utils → all:** `GET /api/platform-status` HTTP probes for admin dashboard.

### Booking model (canonical)

- Single table: **`engagements`** with `booking_type`: `ON_DEMAND`, `SHORT_TERM`, `MONTHLY`.
- Execution: **`service_days`** per calendar day; provider start/complete via engagement-service API.
- See [ENGAGEMENT_CANONICAL.md](./ENGAGEMENT_CANONICAL.md).

### Deployment

| Env | Mechanism |
|-----|-----------|
| **dev** | Render deploy hooks (`.github/workflows/deploy-backend.yml`) |
| **prod** | EC2 versioned releases + PM2 or Docker (providers) |
| **DB** | **Deploy Backend** with `run_migrations: true` or `npm run db:migrate` |
| **rollback** | EC2 only (`.github/workflows/rollback-backend.yml`) |

**Gap:** CI is **manual `workflow_dispatch` only** — no automated test/lint on push.

---

## 2. Coding standards (current state)

| Area | Status | Target for prod |
|------|--------|-----------------|
| TypeScript | **reviews** only (`strict: true`) | Extend gradually or keep JS services documented |
| ESLint / Prettier | Not enforced repo-wide | Add root config + CI |
| Tests | Effectively **none** (placeholder scripts) | Smoke + payment/webhook + booking lifecycle |
| Error responses | Structured JSON in providers/coupons | Hide `debugMessage` in production |
| Request validation | Ad hoc per route | Shared schema validation (Zod/Joi) on mutating APIs |
| Auth | Auth0 in **UI only**; most APIs **unauthenticated** | JWT middleware on all protected routes |

### Env configuration pattern

- **Local:** repo-root `.env.local` → `scripts/postgres-env.cjs` fans out to services.
- **Prod:** `PROD_ENV_*` multiline secrets on EC2 (see [DEPLOYMENT](./DEPLOYMENT.md)).
- **Rule:** Never commit real credentials; examples must use `localhost` placeholders only.

---

## 3. Migrations & database

### Authority

- **Canonical SQL:** `database/` submodule → [DB_Migrations](https://github.com/ServEase-Innovations/DB_Migrations).
- **Runner:** `npm run db:migrate` → `_serveaso_schema_migrations` + Prisma (tickets).
- **Services must not apply DDL on startup** (payments `initDB` is no-op; tickets fail-fast if tables missing).

### SQL sequence (incremental)

`010` … `095` (baseline + ordered patches). Recent:

| File | Purpose |
|------|---------|
| `096_coupon_booking_conditions.sql` | `booking_condition`, `nth_booking` on coupons |
| `097_maid_cook_promo99_coupons.sql` | Seed MAID99 / COOK99 promos |

**Before prod:** run migrate on prod DB and verify `_serveaso_schema_migrations` includes all files.

### Prisma per service

| Service | Central migrate | Notes |
|---------|-----------------|-------|
| tickets | Yes (`database/prisma/tickets`) | Good pattern |
| coupons | **No** — full DB introspection schema | **Risk** on shared DB; trim to coupon tables only |
| reviews | Separate DB often | Not core `serveaso` |

### Coupons workaround (remove after 096 stable)

- `services/coupons/src/scripts/patchCouponSchema.js` runs `ALTER TABLE` on boot — contradicts central-migration principle. Remove once `096` is applied everywhere.

### Pre-launch DB checklist

- [ ] `npm run db:migrate` on **prod** with `PROD_DATABASE_URL`
- [ ] Confirm `engagements`, `service_days`, `in_app_notifications`, `support_tickets` exist
- [ ] Confirm coupon columns from `096` exist (or coupons service will error)
- [ ] Document prod connection strings per service (shared vs reviews-isolated)
- [ ] Backup strategy + restore drill documented

---

## 4. Security (must fix before prod)

### P0 — blockers

- [x] **S1** — Auth0 M2M secret: moved to `AUTH0_*` env via `lib/auth0Management.js` *(verified: `/authO` user creation works with env config)*
- [x] **S2** — Razorpay webhook: HMAC via `razorpayWebhook.service.js` + `RAZORPAY_WEBHOOK_SECRET` *(verified: Razorpay Dashboard webhook deliveries succeed)*
- [x] **S3** — Admin / settings APIs protected via `X-Admin-Push-Secret` (`ADMIN_PUSH_SECRET`); public `GET /api/platform-settings/public` for cancellation policy only
- [x] **S4** — Default dev secrets in prod path: `validateProductionSecrets` in payments + utils; rejects `serveaso-test-push-secret`, missing `RAZORPAY_WEBHOOK_SECRET`, Razorpay test key defaults, skip-verify flags
- [x] **S5** — Real IPs/passwords in `.env.example` files: replaced with `127.0.0.1` / `your_*` placeholders
- [x] **S6** — CORS `*` / permissive (providers, payments, utils, coupons): `CORS_ORIGINS` env; prod startup validation
- [x] **S7** — Socket.IO origins in `payments/index.js`: uses `CORS_ORIGINS` / `SOCKET_IO_ORIGINS`; utils WebSocket `verifyClient`

### P1 — high

- [x] **S8** — JWT on mutating APIs: Auth0 `express-jwt` on payments + providers (registration, pricing quote, webhooks exempt); set `AUTH0_DOMAIN` + `AUTH0_AUDIENCE`
- [x] **S9** — `debugMessage` in API errors: stripped in production (providers, coupons)
- [x] **S10** — Postgres `rejectUnauthorized: false` (coupons + providers): AWS RDS CA bundle + strict TLS in prod (`postgresSsl.js`, `certs/rds-global-bundle.pem`)
- [x] **S11** — Customer payment data exposure: role-based response redaction (payments + providers `responseRedaction.js`; Razorpay IDs stripped from verify; provider discovery omits email/phone/bank/KYC)

---

## 5. Observability & operations

| Capability | Status |
|------------|--------|
| Prometheus `/metrics` | payments, providers, coupons, preferences, utils |
| Structured logging | payments, providers, coupons, utils |
| Per-service `/health` + `/ready` | payments, providers, coupons, utils — **done**; preferences, reviews, tickets vary |
| Platform status | utils `GET /api/platform-status` (admin only) |
| Prod alerting | **Not defined** — Grafana stacks exist for local Docker only |

### Pre-launch ops checklist

- [ ] `GET /health` + DB ping (`/ready`) on every service
- [ ] Render/EC2 health checks wired
- [ ] Log aggregation (CloudWatch / Loki) + error alerting
- [ ] Razorpay webhook failure alerts
- [ ] Runbook: deploy, rollback, migrate, on-call contacts

---

## 6. Feature & config completeness (recent work)

Ensure prod has admin-configured values and running schedulers:

| Feature | Depends on | Ready |
|---------|------------|-------|
| Cancellation policy | utils platform settings + payments cancel API + UI | [ ] |
| Overdue start reminders | payments scheduler (`OVERDUE_START_REMINDER_ENABLED`), `UTILS_SERVICE_URL`, optional Twilio/FCM | [ ] |
| Coupon booking conditions | SQL `096` + coupons service | [ ] |
| FCM push | utils Firebase credentials + `ADMIN_PUSH_SECRET` | [ ] |
| Auth0 role sync (customer create) | providers API + UI header flow | [ ] |

---

## 7. Execution plan — one item at a time

Mark `[x]` when done. Work in order within each phase.

### Phase 0 — Blockers (week 1)

- [x] **Step 1 · S1** — Auth0 M2M creds in env; removed from `mongoDBControllers.js` *(utils — verified locally)*
- [x] **Step 2 · S2** — Verified Razorpay webhook; tested in Razorpay Dashboard *(payments)*
- [x] **Step 3 · S5** — Scrubbed `.env.example` files (no real hosts/secrets) *(monorepo + service submodules)*
- [x] **Step 4 · S4** — Production secret validation at startup (payments + utils) *(set `INTERNAL_NOTIFY_SECRET`, `ADMIN_PUSH_SECRET`, Razorpay keys + webhook secret on prod)*
- [ ] **Step 5 · DB-1** — Run `db:migrate` on prod; verify 096/097 applied *(DevOps, ~2h)*
- [x] **Step 6 · S3** — Protect platform-settings + destructive utils routes + payments `/api/admin/*` *(set `REACT_APP_ADMIN_PUSH_SECRET` in UI build env)*

### Phase 1 — Secure & stable (week 2)

- [x] **Step 7 · S6–S7** — Lock CORS + Socket.IO to prod domains via `CORS_ORIGINS` *(payments, providers, utils, coupons)*
- [x] **Step 8 · S8** — JWT middleware on mutating APIs (payments + providers) *(set `AUTH0_DOMAIN`, `AUTH0_AUDIENCE`)*
- [x] **Step 9 · OPS-1** — `/health` + `/ready` on payments, providers, coupons, utils
- [x] **Step 10 · ENV-1** — [ENV_MATRIX.md](./ENV_MATRIX.md): every `REACT_APP_*` and service URL (DEV vs PROD)
- [x] **Step 11 · S9** — Gate `debugMessage` behind non-production *(providers, coupons)*
- [ ] **Step 12 · DB-2** — Remove coupons `patchCouponSchema` boot DDL after 096 verified *(coupons, ~2h)*

### Phase 2 — Quality & observability (week 3–4)

- [x] **Step 13 · CI-1** — GitHub Action on PR: lint + typecheck (reviews) + secret scan *(`.github/workflows/pr-checks.yml`)*
- [x] **Step 14 · TEST-1** — Integration tests: health, webhook HMAC, create engagement (`tests/integration/`, `npm run test:integration`)
- [ ] **Step 15 · OPS-2** — Prod metrics scrape + alert rules (5xx, webhook failures, DB down) *(DevOps, ~2d)*
- [ ] **Step 16 · DB-3** — Trim coupons Prisma schema to coupon tables only *(coupons, ~1d)*
- [ ] **Step 17 · SEC-1** — Rate limiting + `helmet` on public Express apps *(backend, ~1d)*

### Phase 3 — Polish (post-launch or parallel)

- [ ] **Step 18 · STD-1** — Root ESLint + Prettier + pre-commit
- [ ] **Step 19 · TEST-2** — E2E: book → pay → provider accept → start → complete
- [ ] **Step 20 · ARCH-1** — Optional BFF or API gateway if CORS/auth complexity grows
- [ ] **Step 21 · DOC-1** — Customer-facing SLA + incident runbook

---

## 8. Go / no-go gate

**Do not send production customer traffic until all are checked:**

- [ ] S1–S4 and S2 (webhook) complete
- [ ] Prod DB migrated through latest SQL (including 096/097)
- [ ] All prod env vars set (no localhost fallbacks)
- [ ] CORS + Socket.IO allow production origins
- [ ] Health checks pass on all deployed services
- [ ] Smoke test: register → book → pay → provider flow on **prod-like** env

---

## 9. Quick reference — who owns what

```text
Bookings / payments / wallets / Socket.IO  → services/payments
Customers / providers / vendors            → services/providers
Coupons                                    → services/coupons
User prefs                                 → services/preferences
Email / push / platform settings / admin   → services/utils
Reviews                                    → services/reviews
Support tickets                            → services/tickets
SQL migrations                             → database/ (DB_Migrations)
Web + mobile UI                            → apps/servase-ui, apps/servease-ios
Deploy & migrate                           → .github/workflows/, docs/DEPLOYMENT.md
```

---

*Last updated: 2026-06-07 — S9 + ENV-1 done. Phase 0 still needs DB-1. See [ENV_MATRIX.md](./ENV_MATRIX.md) for Render/EC2 configuration.*
