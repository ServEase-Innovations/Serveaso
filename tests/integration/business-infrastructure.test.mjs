import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls } from "./lib/config.mjs";
import { getHealth, getReady, httpJson } from "./lib/http.mjs";

const infraServices = [
  ["tickets", serviceUrls.tickets],
  ["preferences", serviceUrls.preferences],
  ["chat", serviceUrls.chat],
  ["imageUploader", serviceUrls.imageUploader],
];

describe("Infrastructure services — health & readiness", () => {
  for (const [name, baseUrl] of infraServices) {
    it(`${name} GET /health returns ok`, async () => {
      const { status, json } = await getHealth(name, baseUrl);
      assert.equal(status, 200, `${name} /health at ${baseUrl}`);
      assert.equal(json?.status, "ok");
      if (name === "imageUploader") {
        assert.equal(json?.service, "image-uploader");
      } else {
        assert.equal(json?.service, name);
      }
    });
  }

  it("preferences GET /ready — DB connected", async () => {
    const { status, json } = await getReady("preferences", serviceUrls.preferences);
    assert.equal(status, 200);
    assert.equal(json?.status, "ready");
  });

  it("reviews GET /ready — Postgres connected", async () => {
    const { status, json } = await getReady("reviews", serviceUrls.reviews);
    assert.equal(status, 200);
    assert.equal(json?.status, "ready");
  });

  it("coupons GET /ready — Postgres connected", async () => {
    const { status, json } = await getReady("coupons", serviceUrls.coupons);
    assert.equal(status, 200);
    assert.equal(json?.status, "ready");
  });

  it("chat GET /ready — Mongo connected", async () => {
    const { status, json } = await getReady("chat", serviceUrls.chat);
    assert.equal(status, 200);
    assert.equal(json?.status, "ready");
  });

  it("imageUploader GET /ready responds", async (t) => {
    const { status, json } = await getReady("image-uploader", serviceUrls.imageUploader);
    if (status === 404) {
      return t.skip("image-uploader /ready not deployed");
    }
    assert.equal(status, 200);
    assert.equal(json?.status, "ready");
  });

  it("tickets service is alive", async () => {
    const { status, json } = await getHealth("tickets", serviceUrls.tickets);
    assert.equal(status, 200);
    assert.equal(json?.service, "tickets");
  });

  it("imageUploader exposes API docs", async () => {
    const { status } = await httpJson(
      "GET",
      `${serviceUrls.imageUploader}/api-docs/`
    );
    assert.ok(status === 200 || status === 301, `api-docs status ${status}`);
  });
});
