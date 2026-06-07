import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls, getTestProviderId } from "./lib/config.mjs";
import { httpJson } from "./lib/http.mjs";

describe("Reviews service", () => {
  it("GET /reviews/providers/:id/reviews returns provider rating summary", async () => {
    const providerId = getTestProviderId();
    const { status, json } = await httpJson(
      "GET",
      `${serviceUrls.reviews}/reviews/providers/${providerId}/reviews`
    );
    assert.equal(status, 200);
    assert.equal(json?.success, true);
    assert.ok(json?.provider);
    assert.equal(typeof json.provider.rating, "number");
    assert.ok(Array.isArray(json?.reviews));
  });

  it("GET /reviews/eligibility returns eligibility decision", async () => {
    const { status, json } = await httpJson(
      "GET",
      `${serviceUrls.reviews}/reviews/eligibility?serviceType=ON_DEMAND&engagementId=1`
    );
    assert.equal(status, 200);
    assert.equal(typeof json?.eligible, "boolean");
    assert.ok(json?.reason || json?.eligible === true);
  });
});
