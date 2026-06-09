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

/**
 * End-to-end booking path: quote → (optional) create engagement.
 * Validates pricing output is usable before checkout.
 */
describe("Booking flow — quote then create (payments)", () => {
  it("on-demand COOK quote total matches create-engagement base_amount band", async (t) => {
    const startDate = futureYmd();
    const startTime = "10:00";
    const durationMinutes = 120;

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

    const quoteRes = await httpJson("POST", `${serviceUrls.payments}/api/v2/pricing/quote`, {
      body: {
        serviceType: "COOK",
        bookingType: "ON_DEMAND",
        startDate,
        durationHours: 2,
        ratePreference: "mid",
      },
    });
    assert.equal(quoteRes.status, 200);
    const quotedTotal = Number(quoteRes.json?.total);
    assert.ok(quotedTotal > 0);

    const createRes = await httpJson("POST", `${serviceUrls.payments}/api/v2/createEngagements`, {
      headers: internalAuthHeaders(),
      body: {
        customerid: getTestCustomerId(),
        start_date: startDate,
        start_time: startTime,
        booking_type: "ON_DEMAND",
        service_type: "COOK",
        base_amount: quotedTotal,
        duration_minutes: durationMinutes,
        ...onDemandLocationFields(),
      },
    });

    assert.equal(createRes.status, 201, JSON.stringify(createRes.json));
    assert.ok(createRes.json?.engagement_id > 0);
    assert.ok(createRes.json?.razorpay_order_id);
    assert.ok(Number(createRes.json?.total_amount) >= quotedTotal);
  });
});
