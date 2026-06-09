import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls, getTestCustomerId } from "./lib/config.mjs";
import { httpJson } from "./lib/http.mjs";
import { internalAuthHeaders } from "./lib/auth.mjs";
import { futureYmd } from "./lib/dates.mjs";
import {
  onDemandLocationFields,
  skipUnlessOnDemandProvidersAvailable,
} from "./lib/onDemandFixtures.mjs";

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
    if (status === 404) {
      assert.match(json?.error || "", /customer not found/i);
      return;
    }
    if (status === 409) {
      // Older deployments validate on-demand location before customer lookup.
      assert.ok(
        json?.code === "INVALID_COORDINATES" || json?.code === "NO_PROVIDERS_NEARBY",
        `expected customer 404 or on-demand availability block, got ${status}: ${JSON.stringify(json)}`
      );
      return;
    }
    assert.ok(
      status === 500 && /customer not found/i.test(json?.error || ""),
      `expected 404 (or legacy 500) for unknown customer, got ${status}: ${JSON.stringify(json)}`
    );
  });

  it("creates ON_DEMAND engagement for DEV test customer", async (t) => {
    const startDate = futureYmd();
    const startTime = "09:00";
    const durationMinutes = 60;

    if (
      !(await skipUnlessOnDemandProvidersAvailable(t, {
        serviceType: "COOK",
        startDate,
        startTime,
        durationMinutes,
      }))
    ) {
      return;
    }

    const customerId = getTestCustomerId();

    const { status, json } = await httpJson("POST", createUrl, {
      headers: internalAuthHeaders(),
      body: {
        customerid: customerId,
        start_date: startDate,
        start_time: startTime,
        booking_type: "ON_DEMAND",
        service_type: "COOK",
        base_amount: 99,
        duration_minutes: durationMinutes,
        ...onDemandLocationFields(),
      },
    });

    assert.equal(status, 201, JSON.stringify(json));
    assert.ok(json?.engagement_id > 0);
    assert.ok(json?.razorpay_order_id);
    assert.ok(json?.razorpay_key_id);
    assert.ok(Number(json?.total_amount) > 0);
  });
});
