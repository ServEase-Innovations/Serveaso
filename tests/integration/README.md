# Integration tests (TEST-1)

Smoke tests against **DEV** Render URLs: health, Razorpay webhook HMAC, and create engagement.

## Run locally

```bash
# From monorepo root (uses ENV_MATRIX defaults)
npm run test:integration

# Optional secrets for full coverage
export RAZORPAY_WEBHOOK_SECRET='...'          # live signed webhook test
export INTEGRATION_TEST_CUSTOMER_ID='54'      # happy-path create (creates PAYMENT_PENDING row)
export INTEGRATION_INTERNAL_SECRET='...'      # if DEV enforces JWT on mutations

npm run test:integration
```

## What is tested

| Test file | Coverage |
|-----------|----------|
| `health.test.mjs` | `/health` on utils, coupons, reviews, payments, providers; `/ready` on payments |
| `webhook-hmac.test.mjs` | Unit HMAC verify + live webhook probes |
| `create-engagement.test.mjs` | Validation 400, unknown customer 404, optional create 201 |

## CI/CD (GitHub Actions)

Workflow: **Integration Tests (DEV)** (`.github/workflows/integration-tests.yml`)

| Trigger | When |
|---------|------|
| **Push to `main`** | Changes under `tests/integration/`, payments webhook tests, or workflow file |
| **Daily schedule** | 06:00 UTC — continuous DEV smoke |
| **Deploy Backend → dev** | After successful dev deploy (`run_smoke_tests: true`, default) |
| **Manual** | Actions → Run workflow; optional happy-path create via input |

URL overrides (optional repo secrets): `DEV_PAYMENTS_URL`, `DEV_PROVIDERS_URL`, `DEV_UTILS_URL`, etc.  
Unset secrets fall back to defaults in `lib/config.mjs`.

## Notes

- **payments/providers `/health`**: requires OPS-1 deploy on Render; liveness probes used as fallback.
- **Webhook verify on DEV**: `payments-vyqp` enforces HMAC; unit tests always validate the algorithm.
- **Happy-path create** inserts a real `PAYMENT_PENDING` engagement — use a dedicated test customer id.
