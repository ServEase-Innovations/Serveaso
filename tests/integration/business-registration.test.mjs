import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls } from "./lib/config.mjs";
import { httpJson } from "./lib/http.mjs";

const checkEmailUrl = `${serviceUrls.providers}/api/service-providers/check-email`;
const checkMobileUrl = `${serviceUrls.providers}/api/service-providers/check-mobile`;

describe("Registration & identity checks (providers)", () => {
  it("POST check-email returns exists boolean for probe email", async () => {
    const { status, json } = await httpJson("POST", checkEmailUrl, {
      body: { email: "integration-probe@serveaso.test" },
    });
    assert.equal(status, 200);
    assert.equal(typeof json?.exists, "boolean");
  });

  it("POST check-email requires email", async () => {
    const { status, json } = await httpJson("POST", checkEmailUrl, { body: {} });
    assert.equal(status, 400);
    assert.match(json?.message || "", /email/i);
  });

  it("POST check-mobile returns exists boolean", async () => {
    const { status, json } = await httpJson("POST", checkMobileUrl, {
      body: { mobile: "9999999999" },
    });
    assert.equal(status, 200);
    assert.equal(typeof json?.exists, "boolean");
  });

  it("POST check-mobile requires mobile", async () => {
    const { status, json } = await httpJson("POST", checkMobileUrl, { body: {} });
    assert.equal(status, 400);
    assert.match(json?.message || "", /mobile/i);
  });
});
