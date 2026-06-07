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

## CI

GitHub Actions → **Integration Tests (DEV)** → Run workflow (manual).  
Requires repo secrets: `DEV_PAYMENTS_URL`, etc. (optional overrides) and `RAZORPAY_WEBHOOK_SECRET` / `INTEGRATION_TEST_CUSTOMER_ID` for optional tests.

## Notes

- **payments/providers `/health`**: requires OPS-1 deploy on Render; tests fail with a redeploy hint if still 404.
- **Webhook verify on DEV**: if `SKIP_RAZORPAY_WEBHOOK_VERIFY` is set, live HMAC enforcement is skipped; unit tests still validate the algorithm.
- **Happy-path create** inserts a real `PAYMENT_PENDING` engagement — use a dedicated test customer id.
