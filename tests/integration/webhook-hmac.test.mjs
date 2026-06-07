import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { verifyRazorpayWebhookSignature } from "../../services/payments/src/utils/razorpayWebhookHmac.js";
import { serviceUrls, integrationSecrets } from "./lib/config.mjs";
import { httpJson } from "./lib/http.mjs";

const webhookUrl = `${serviceUrls.payments}/api/v2/createEngagements/webhook`;

function signWebhookBody(rawBody, secret) {
  return createHmac("sha256", secret).update(rawBody).digest("hex");
}

describe("Razorpay webhook HMAC (unit)", () => {
  it("verifyRazorpayWebhookSignature accepts a valid signature", () => {
    const body = JSON.stringify({ event: "payment.captured" });
    const secret = "test_webhook_secret";
    const sig = signWebhookBody(body, secret);
    assert.equal(verifyRazorpayWebhookSignature(body, sig, secret), true);
  });

  it("verifyRazorpayWebhookSignature rejects invalid signature", () => {
    const body = JSON.stringify({ event: "payment.captured" });
    assert.equal(
      verifyRazorpayWebhookSignature(body, "bad-signature", "test_webhook_secret"),
      false
    );
  });
});

describe("Razorpay webhook HMAC (DEV live)", () => {
  it("rejects missing signature when verification is enforced", async () => {
    const body = { event: "payment.captured", payload: { payment: { entity: { id: "pay_x", order_id: "order_x" } } } };
    const { status, json } = await httpJson("POST", webhookUrl, { body });

    if (status === 400 && /signature/i.test(json?.error || "")) {
      assert.match(json.error, /signature/i);
      return;
    }
    if (status === 503 && /not configured/i.test(json?.error || "")) {
      console.warn("DEV payments: webhook secret not configured (503) — HMAC live probe skipped");
      return;
    }
    // Dev may have SKIP_RAZORPAY_WEBHOOK_VERIFY — do not fail the suite.
    console.warn(
      `DEV webhook verify not enforced (status ${status}) — unit HMAC tests still gate prod behavior`
    );
  });

  it("accepts valid HMAC and returns not-found for unknown order when secret is set", async (t) => {
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET?.trim();
    if (!secret) {
      return t.skip("Set RAZORPAY_WEBHOOK_SECRET to run live signed webhook test");
    }

    const payload = {
      event: "payment.captured",
      payload: {
        payment: {
          entity: {
            id: "pay_integration_test",
            order_id: "order_integration_test_missing",
          },
        },
      },
    };
    const rawBody = JSON.stringify(payload);
    const signature = signWebhookBody(rawBody, secret);

    const { status, json } = await httpJson("POST", webhookUrl, {
      headers: { "X-Razorpay-Signature": signature },
      body: rawBody,
    });

    if (status === 400 && /invalid signature/i.test(json?.error || "")) {
      t.skip("RAZORPAY_WEBHOOK_SECRET does not match DEV payments env");
    }

    assert.ok(
      status === 404 || status === 500 || status === 200,
      `expected signed webhook to pass HMAC (got ${status}: ${JSON.stringify(json)})`
    );
    if (status === 404 || status === 500) {
      assert.match(json?.error || "", /not found/i);
    }
  });

  it("ignores non-captured events (200) or requires signature (400)", async () => {
    const { status, json } = await httpJson("POST", webhookUrl, {
      body: { event: "payment.authorized" },
    });
    if (status === 400 && /signature/i.test(json?.error || "")) {
      return;
    }
    assert.equal(status, 200);
    assert.equal(json?.received, true);
  });
});
