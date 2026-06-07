import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls } from "./lib/config.mjs";
import { httpJson } from "./lib/http.mjs";

describe("Coupons service", () => {
  it("GET /api/coupons/all returns coupon list", async () => {
    const { status, json } = await httpJson(
      "GET",
      `${serviceUrls.coupons}/api/coupons/all`
    );
    assert.equal(status, 200);
    assert.equal(json?.success, true);
    assert.ok(Array.isArray(json?.data));
  });

  it("POST /api/coupons/validate rejects unknown coupon code", async () => {
    const { status, json } = await httpJson(
      "POST",
      `${serviceUrls.coupons}/api/coupons/validate`,
      {
        body: {
          coupon_code: "INTEGRATION_INVALID_PROBE",
          customer_id: 1,
          order_value: 500,
          service_type: "COOK",
        },
      }
    );
    assert.ok(status === 400 || status === 404, `expected client error, got ${status}`);
    assert.equal(json?.success, false);
    assert.ok(json?.code || json?.message);
  });
});

describe("Coupons proxy (payments → coupons)", () => {
  it("GET /api/coupons/customer/:id returns structured customer coupons", async () => {
    const customerId = process.env.INTEGRATION_TEST_CUSTOMER_ID?.trim() || "1";
    const { status, json } = await httpJson(
      "GET",
      `${serviceUrls.payments}/api/coupons/customer/${customerId}?serviceType=COOK`
    );
    assert.equal(status, 200);
    assert.equal(json?.success, true);
    assert.ok(json?.data?.customer_id != null);
    assert.ok(Array.isArray(json?.data?.coupons));
  });
});
