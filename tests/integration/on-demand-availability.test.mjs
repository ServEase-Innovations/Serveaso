import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls } from "./lib/config.mjs";
import { httpJson } from "./lib/http.mjs";
import { internalAuthHeaders } from "./lib/auth.mjs";
import { futureYmd } from "./lib/dates.mjs";

const availabilityUrl = `${serviceUrls.payments}/api/v2/createEngagements/on-demand-availability`;
const createUrl = `${serviceUrls.payments}/api/v2/createEngagements`;

describe("on-demand provider availability (DEV live)", () => {
  it("GET on-demand-availability rejects missing service_type", async () => {
    const url = `${availabilityUrl}?lat=12.97&lng=77.59&start_date=${futureYmd()}&start_time=09:00`;
    const { status, json } = await httpJson("GET", url, {
      headers: internalAuthHeaders(),
    });
    assert.equal(status, 400);
    assert.match(json?.error || "", /service_type/i);
  });

  it("GET on-demand-availability reports unavailable in remote ocean coordinates", async () => {
    const url = `${availabilityUrl}?lat=-15.5&lng=-140.2&service_type=COOK&start_date=${futureYmd()}&start_time=09:00`;
    const { status, json } = await httpJson("GET", url, {
      headers: internalAuthHeaders(),
    });
    assert.equal(status, 200, JSON.stringify(json));
    assert.equal(json?.available, false);
    assert.equal(json?.count, 0);
    assert.equal(json?.code, "NO_PROVIDERS_NEARBY");
  });

  it("POST createEngagements blocks ON_DEMAND without nearby providers", async () => {
    const { getTestCustomerId } = await import("./lib/config.mjs");
    const customerId = getTestCustomerId();

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
        latitude: -15.5,
        longitude: -140.2,
      },
    });

    assert.equal(status, 409, JSON.stringify(json));
    assert.equal(json?.code, "NO_PROVIDERS_NEARBY");
    assert.match(json?.error || "", /no service providers|valid service location/i);
  });
});
