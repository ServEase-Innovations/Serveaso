import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls } from "./lib/config.mjs";
import { httpJson } from "./lib/http.mjs";
import { internalAuthHeaders } from "./lib/auth.mjs";
import { futureYmd } from "./lib/dates.mjs";

const createUrl = `${serviceUrls.payments}/api/v2/createEngagements`;

describe("POST /api/v2/createEngagements (DEV live)", () => {
  it("returns 400 when required fields are missing", async () => {
    const { status, json } = await httpJson("POST", createUrl, {
      headers: internalAuthHeaders(),
      body: {},
    });
    assert.equal(status, 400);
    assert.match(json?.error || "", /missing required fields/i);
  });

  it("returns 404 for unknown customer id", async () => {
    const { status, json } = await httpJson("POST", createUrl, {
      headers: internalAuthHeaders(),
      body: {
        customerid: 999_999_999,
        start_date: futureYmd(),
        start_time: "07:00",
        booking_type: "ON_DEMAND",
        service_type: "COOK",
        base_amount: 100,
      },
    });
    assert.ok(
      status === 404 || (status === 500 && /customer not found/i.test(json?.error || "")),
      `expected 404 (or legacy 500) for unknown customer, got ${status}: ${JSON.stringify(json)}`
    );
    assert.match(json?.error || "", /customer not found/i);
  });

  it("creates ON_DEMAND engagement when INTEGRATION_TEST_CUSTOMER_ID is set", async (t) => {
    const raw = process.env.INTEGRATION_TEST_CUSTOMER_ID?.trim();
    if (!raw) {
      return t.skip("Set INTEGRATION_TEST_CUSTOMER_ID to run happy-path create test");
    }
    const customerId = Number(raw);
    if (!Number.isFinite(customerId) || customerId <= 0) {
      return t.skip("INTEGRATION_TEST_CUSTOMER_ID must be a positive integer");
    }

    const { status, json } = await httpJson("POST", createUrl, {
      headers: internalAuthHeaders(),
      body: {
        customerid: customerId,
        start_date: futureYmd(),
        start_time: "09:00",
        booking_type: "ON_DEMAND",
        service_type: "COOK",
        base_amount: 99,
        duration_minutes: 60,
      },
    });

    assert.equal(status, 201, JSON.stringify(json));
    assert.ok(json?.engagement_id > 0);
    assert.ok(json?.razorpay_order_id);
    assert.ok(json?.razorpay_key_id);
    assert.ok(Number(json?.total_amount) > 0);
  });
});
