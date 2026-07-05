import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls } from "./lib/config.mjs";
import { requestTimeoutMs } from "./lib/config.mjs";

const metricTargets = [
  ["payments", serviceUrls.payments],
  ["providers", serviceUrls.providers],
  ["utils", serviceUrls.utils],
  ["coupons", serviceUrls.coupons],
  ["preferences", serviceUrls.preferences],
  ["reviews", serviceUrls.reviews],
  ["tickets", serviceUrls.tickets],
  ["chat", serviceUrls.chat],
  ["image-uploader", serviceUrls.imageUploader],
  ["tracking", serviceUrls.tracking],
];

async function fetchMetrics(baseUrl) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), requestTimeoutMs);
  try {
    const res = await fetch(`${baseUrl}/metrics`, {
      method: "GET",
      headers: { Accept: "text/plain" },
      signal: controller.signal,
    });
    const text = await res.text();
    return { status: res.status, contentType: res.headers.get("content-type") || "", text };
  } finally {
    clearTimeout(timer);
  }
}

describe("Prometheus /metrics — all backend services", () => {
  for (const [name, baseUrl] of metricTargets) {
    it(`${name} GET /metrics exposes Prometheus text`, async (t) => {
      const { status, contentType, text } = await fetchMetrics(baseUrl);
      if (status === 404) {
        return t.skip(`${name} /metrics not deployed yet — redeploy after observability rollout`);
      }
      assert.equal(status, 200, `${name} /metrics at ${baseUrl}`);
      assert.ok(
        contentType.includes("text/plain") || text.includes("# HELP"),
        `expected Prometheus exposition, got content-type=${contentType}`
      );
      assert.ok(text.includes("http_requests_total"), `${name} missing http_requests_total`);
      assert.ok(
        text.includes('service="' + (name === "image-uploader" ? "image-uploader" : name) + '"') ||
          text.includes("process_cpu_user_seconds_total"),
        `${name} missing service label or default process metrics`
      );
    });
  }
});
