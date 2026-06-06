# Production readiness — ServEase / Serveaso

Living checklist for going live. Work through items **in order** (P0 → P3). Mark items `[x]` when complete; leave `[ ]` when not done.

**Related docs:** [README](../README.md) · [DEPLOYMENT](./DEPLOYMENT.md) · [DATABASE_MIGRATIONS](./DATABASE_MIGRATIONS.md) · [DATABASE_SCHEMA](./DATABASE_SCHEMA.md) · [ENGAGEMENT_CANONICAL](./ENGAGEMENT_CANONICAL.md)

---

## Progress summary

| Area | Status |
|------|--------|
| Phase 0 — Blockers | 4 / 6 |
| Phase 1 — Secure & stable | 0 / 6 |
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

**Next:** DB-1 (prod migrations) or S3 (protect admin/platform-settings routes).

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
| **DB** | Manual **Migrate Database** workflow or `npm run db:migrate` |
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
- [ ] **S3** — Open admin / settings APIs (utils: `PUT /api/platform-settings`, `/delete-all`, `/records/*`; payments admin routes): require Auth0 JWT + admin role or shared secret
- [x] **S4** — Default dev secrets in prod path: `validateProductionSecrets` in payments + utils; rejects `serveaso-test-push-secret`, missing `RAZORPAY_WEBHOOK_SECRET`, Razorpay test key defaults, skip-verify flags
- [x] **S5** — Real IPs/passwords in `.env.example` files: replaced with `127.0.0.1` / `your_*` placeholders
- [ ] **S6** — CORS `*` / permissive (providers, payments, utils): explicit production origins only
- [ ] **S7** — Socket.IO origins in `payments/index.js` (localhost + Netlify only): add production web + mobile origins

### P1 — high

- [ ] **S8** — No JWT on business APIs: Auth0 `express-jwt` (or API gateway) on providers, payments, coupons, reviews
- [ ] **S9** — `debugMessage` in API errors: strip in production responses
- [ ] **S10** — Postgres `rejectUnauthorized: false` (coupons): use proper CA bundle
- [ ] **S11** — Customer payment data exposure: audit all roles (SP API already cleaned)

---

## 5. Observability & operations

| Capability | Status |
|------------|--------|
| Prometheus `/metrics` | payments, providers, coupons, preferences, utils |
| Structured logging | payments, providers, coupons, utils |
| Per-service `/health` | preferences, reviews, tickets — **missing on payments, providers, coupons** |
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
- [ ] **Step 6 · S3** — Protect platform-settings + destructive utils routes *(utils, ~4h)*

### Phase 1 — Secure & stable (week 2)

- [ ] **Step 7 · S6–S7** — Lock CORS + Socket.IO to prod domains *(payments, providers, utils, UI, ~3h)*
- [ ] **Step 8 · S8** — JWT middleware on mutating APIs (start with payments + providers) *(backend, 2–3d)*
- [ ] **Step 9 · OPS-1** — Add `/health` + `/ready` to payments, providers, coupons, utils *(backend, ~1d)*
- [ ] **Step 10 · ENV-1** — Prod env matrix doc: every `REACT_APP_*` and service URL *(DevOps + UI, ~2h)*
- [ ] **Step 11 · S9** — Gate `debugMessage` behind non-production *(providers, coupons, ~2h)*
- [ ] **Step 12 · DB-2** — Remove coupons `patchCouponSchema` boot DDL after 096 verified *(coupons, ~2h)*

### Phase 2 — Quality & observability (week 3–4)

- [ ] **Step 13 · CI-1** — GitHub Action on PR: lint + typecheck (reviews) + secret scan *(monorepo, ~1d)*
- [ ] **Step 14 · TEST-1** — Integration tests: payment verify, webhook, engagement create/cancel *(payments, ~2d)*
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

*Last updated: 2026-06-02 — S1–S2, S4–S5 complete. Next: Step 5 · DB-1 or Step 6 · S3.*
