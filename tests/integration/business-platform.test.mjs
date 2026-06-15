import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls } from "./lib/config.mjs";
import { httpJson } from "./lib/http.mjs";

describe("Platform & customer identity (utils)", () => {
  it("GET /api/platform-settings/public returns cancellation policy and footer", async () => {
    const { status, json } = await httpJson(
      "GET",
      `${serviceUrls.utils}/api/platform-settings/public`
    );
    assert.equal(status, 200);
    assert.equal(json?.success, true);
    assert.ok(json?.settings?.cancellation, "expected cancellation policy in public settings");
    assert.ok(
      Number.isFinite(json.settings.cancellation.onDemandMinutesBeforeStart) ||
        json.settings.cancellation.onDemandMinutesBeforeStart != null,
      "expected onDemandMinutesBeforeStart"
    );
    assert.ok(json?.settings?.footer, "expected footer in public settings");
    assert.equal(typeof json.settings.footer.helplinePhone, "string");
    assert.equal(typeof json.settings.footer.joinUsPhone, "string");
    assert.ok(json.settings.footer.social, "expected footer.social");
    assert.equal(typeof json.settings.footer.social.x, "string");
    assert.equal(typeof json.settings.footer.social.instagram, "string");
  });

  it("GET /customer/check-email responds for probe email", async () => {
    const email = encodeURIComponent("integration-probe@serveaso.test");
    const { status, json } = await httpJson(
      "GET",
      `${serviceUrls.utils}/customer/check-email?email=${email}`
    );
    assert.equal(status, 200);
    assert.equal(typeof json?.exists, "boolean");
  });

  it("GET /customer/check-email returns 400 without email", async () => {
    const { status } = await httpJson("GET", `${serviceUrls.utils}/customer/check-email`);
    assert.ok(status === 400 || status === 422, `expected validation error, got ${status}`);
  });
});
