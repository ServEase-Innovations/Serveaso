# Integration tests (TEST-1)

Smoke tests against **DEV** Render URLs covering health, core business APIs, and booking flows.

## Run locally

```bash
npm run test:integration
```

**DEV test fixtures** (built-in defaults — override only for other stacks):

| Variable | Default | Used for |
|----------|---------|----------|
| `INTEGRATION_TEST_CUSTOMER_ID` | `1` | Create engagement, coupons proxy, quote→create flow |
| `INTEGRATION_TEST_PROVIDER_ID` | `2` | Provider reviews summary |

Optional:

```bash
export RAZORPAY_WEBHOOK_SECRET='...'
export INTEGRATION_INTERNAL_SECRET='...'
```

## Test suites

| File | Business area |
|------|----------------|
| `health.test.mjs` | Core service liveness (`/health`, `/ready` fallbacks) |
| `business-infrastructure.test.mjs` | tickets, preferences, chat, image-uploader health + DB readiness |
| `business-platform.test.mjs` | Utils — public platform settings, customer email lookup |
| `business-registration.test.mjs` | Providers — check-email / check-mobile before signup |
| `business-pricing.test.mjs` | Payments — pricing plans, on-demand & monthly quotes |
| `business-coupons.test.mjs` | Coupons list/validate + payments coupon proxy |
| `business-discovery.test.mjs` | Payments — monthly provider search (`nearby-monthly`) |
| `business-reviews.test.mjs` | Reviews — provider ratings list, eligibility |
| `business-booking-flow.test.mjs` | Quote → create engagement (customer id 1) |
| `webhook-hmac.test.mjs` | Razorpay webhook HMAC (unit + live) |
| `create-engagement.test.mjs` | Create engagement validation & error paths |

## CI/CD

Workflow: **Integration Tests (DEV)** — push to `main` (test paths), daily 06:00 UTC, after dev deploy, manual.

URL overrides: optional `DEV_*_URL` repo secrets; defaults in `lib/config.mjs`.

## Notes

- **nearby-monthly**: skipped when DEV returns 500 (known SQL/schema issue to fix on payments).
- **Happy-path create** inserts `PAYMENT_PENDING` for customer **1** on DEV.
