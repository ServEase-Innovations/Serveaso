/**
 * Dev service URLs — override via env for CI or custom stacks.
 * Defaults match docs/ENV_MATRIX.md (Render DEV).
 */
export const serviceUrls = {
  payments: (
    process.env.INTEGRATION_PAYMENTS_URL ||
    process.env.REACT_APP_PAYMENTS_URL ||
    "https://payments-j5id.onrender.com"
  ).replace(/\/$/, ""),
  providers: (
    process.env.INTEGRATION_PROVIDERS_URL ||
    process.env.REACT_APP_PROVIDER_URL ||
    "https://providers-08ug.onrender.com"
  ).replace(/\/$/, ""),
  utils: (
    process.env.INTEGRATION_UTILS_URL ||
    process.env.REACT_APP_UTILS_URL ||
    "https://utils-jo6c.onrender.com"
  ).replace(/\/$/, ""),
  coupons: (
    process.env.INTEGRATION_COUPONS_URL ||
    process.env.REACT_APP_COUPONS_URL ||
    "https://coupons-o26r.onrender.com"
  ).replace(/\/$/, ""),
  reviews: (
    process.env.INTEGRATION_REVIEWS_URL ||
    process.env.REACT_APP_REVIEWS_URL ||
    "https://reviews-19oo.onrender.com"
  ).replace(/\/$/, ""),
};

export const integrationSecrets = {
  webhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET?.trim() || "",
  internalSecret:
    process.env.INTEGRATION_INTERNAL_SECRET?.trim() ||
    process.env.INTERNAL_NOTIFY_SECRET?.trim() ||
    "",
  testCustomerId: Number(process.env.INTEGRATION_TEST_CUSTOMER_ID || 0),
};

export const requestTimeoutMs = Number(process.env.INTEGRATION_TIMEOUT_MS || 45_000);
