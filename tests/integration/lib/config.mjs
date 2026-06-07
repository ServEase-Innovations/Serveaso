/**
 * Dev service URLs — override via env for CI or custom stacks.
 * Defaults match docs/ENV_MATRIX.md (Render DEV).
 */
export const serviceUrls = {
  payments: (
    process.env.INTEGRATION_PAYMENTS_URL ||
    process.env.REACT_APP_PAYMENTS_URL ||
    "https://payments-vyqp.onrender.com"
  ).replace(/\/$/, ""),
  providers: (
    process.env.INTEGRATION_PROVIDERS_URL ||
    process.env.REACT_APP_PROVIDER_URL ||
    "https://providers-k8w7.onrender.com"
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
    "https://reviews-7aal.onrender.com"
  ).replace(/\/$/, ""),
  tickets: (
    process.env.INTEGRATION_TICKETS_URL ||
    process.env.REACT_APP_TICKETS_URL ||
    "https://tickets-3gc8.onrender.com"
  ).replace(/\/$/, ""),
  preferences: (
    process.env.INTEGRATION_PREFERENCES_URL ||
    process.env.REACT_APP_PREFERENCES_URL ||
    "https://preferences.onrender.com"
  ).replace(/\/$/, ""),
  chat: (
    process.env.INTEGRATION_CHAT_URL ||
    process.env.REACT_APP_CHAT_URL ||
    "https://chat-b3wl.onrender.com"
  ).replace(/\/$/, ""),
  imageUploader: (
    process.env.INTEGRATION_IMAGE_UPLOADER_URL ||
    process.env.REACT_APP_IMAGE_UPLOADER_URL ||
    "https://imageuploader-5njj.onrender.com"
  ).replace(/\/$/, ""),
};

/** DEV smoke fixtures — override via env for other stacks. */
export const DEV_TEST_CUSTOMER_ID = 1;
export const DEV_TEST_PROVIDER_ID = 2;

function parsePositiveInt(value, fallback) {
  const raw = value?.trim();
  if (!raw) return fallback;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : fallback;
}

export function getTestCustomerId() {
  return parsePositiveInt(process.env.INTEGRATION_TEST_CUSTOMER_ID, DEV_TEST_CUSTOMER_ID);
}

export function getTestProviderId() {
  return parsePositiveInt(process.env.INTEGRATION_TEST_PROVIDER_ID, DEV_TEST_PROVIDER_ID);
}

export const integrationSecrets = {
  webhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET?.trim() || "",
  internalSecret:
    process.env.INTEGRATION_INTERNAL_SECRET?.trim() ||
    process.env.INTERNAL_NOTIFY_SECRET?.trim() ||
    "",
};

export const requestTimeoutMs = Number(process.env.INTEGRATION_TIMEOUT_MS || 45_000);
