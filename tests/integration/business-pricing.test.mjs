import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls } from "./lib/config.mjs";
import { httpJson } from "./lib/http.mjs";
import { futureYmd, monthAfterYmd } from "./lib/dates.mjs";

const quoteUrl = `${serviceUrls.payments}/api/v2/pricing/quote`;
const plansUrl = `${serviceUrls.payments}/api/v2/pricing/plans`;

describe("Pricing engine (payments)", () => {
  it("GET /api/v2/pricing/plans returns active plans", async () => {
    const { status, json } = await httpJson("GET", plansUrl);
    assert.equal(status, 200);
    assert.equal(json?.success, true);
    assert.ok(Array.isArray(json?.plans));
    assert.ok(json.plans.length > 0, "expected at least one pricing plan on DEV");
  });

  it("GET /api/v2/pricing/plans/MAID/ON_DEMAND returns plan + rules", async () => {
    const { status, json } = await httpJson(
      "GET",
      `${serviceUrls.payments}/api/v2/pricing/plans/MAID/ON_DEMAND`
    );
    assert.equal(status, 200);
    assert.equal(json?.success, true);
    assert.ok(json?.plan?.plan_id || json?.plan?.code);
    assert.ok(Array.isArray(json?.rules));
  });

  it("POST quote — COOK on-demand returns positive total", async () => {
    const { status, json } = await httpJson("POST", quoteUrl, {
      body: {
        serviceType: "COOK",
        bookingType: "ON_DEMAND",
        startDate: futureYmd(),
        durationHours: 2,
        ratePreference: "mid",
      },
    });
    assert.equal(status, 200);
    assert.equal(json?.success, true);
    assert.ok(Number(json?.total) > 0);
    assert.ok(json?.quote?.line_items?.length > 0);
  });

  it("POST quote — MAID monthly returns positive total", async () => {
    const start = futureYmd();
    const end = monthAfterYmd(start);
    const { status, json } = await httpJson("POST", quoteUrl, {
      body: {
        serviceType: "MAID",
        bookingType: "MONTHLY",
        startDate: start,
        endDate: end,
        hoursPerDay: 2,
        ratePreference: "mid",
      },
    });
    assert.equal(status, 200);
    assert.equal(json?.success, true);
    assert.ok(Number(json?.total) > 0);
  });

  it("POST quote rejects missing startDate", async () => {
    const { status, json } = await httpJson("POST", quoteUrl, {
      body: { serviceType: "MAID", bookingType: "ON_DEMAND" },
    });
    assert.ok(status === 400 || status === 500);
    assert.equal(json?.success, false);
    assert.match(json?.error || "", /startDate|required/i);
  });
});
