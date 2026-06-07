import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls } from "./lib/config.mjs";
import { getHealth, getReady, httpJson } from "./lib/http.mjs";

async function assertHealthOrProbe(name, baseUrl, probe) {
  const { status, json } = await getHealth(name, baseUrl);
  if (status === 200 && json?.status === "ok") {
    assert.equal(json.service, name);
    return;
  }

  const probeResult = await probe();
  assert.ok(
    probeResult.ok,
    `${name} /health returned ${status} and liveness probe failed: ${probeResult.detail}`
  );
}

describe("DEV health endpoints", () => {
  it("utils GET /health returns ok", async () => {
    const { status, json } = await getHealth("utils", serviceUrls.utils);
    assert.equal(status, 200);
    assert.equal(json?.status, "ok");
    assert.equal(json?.service, "utils");
  });

  it("coupons GET /health returns ok", async () => {
    const { status, json } = await getHealth("coupons", serviceUrls.coupons);
    assert.equal(status, 200);
    assert.equal(json?.status, "ok");
    assert.equal(json?.service, "coupons");
  });

  it("reviews GET /health returns ok", async () => {
    const { status, json } = await getHealth("reviews", serviceUrls.reviews);
    assert.equal(status, 200);
    assert.equal(json?.status, "ok");
    assert.equal(json?.service, "reviews");
  });

  it("payments is alive (/health or API probe)", async () => {
    await assertHealthOrProbe("payments", serviceUrls.payments, async () => {
      const { status, json } = await httpJson(
        "POST",
        `${serviceUrls.payments}/api/v2/createEngagements`,
        { body: {} }
      );
      if (status === 400 && /missing required fields/i.test(json?.error || "")) {
        return { ok: true };
      }
      return { ok: false, detail: `create probe status ${status}` };
    });
  });

  it("providers is alive (/health or API probe)", async () => {
    await assertHealthOrProbe("providers", serviceUrls.providers, async () => {
      const { status } = await httpJson(
        "POST",
        `${serviceUrls.providers}/api/service-providers/check-email`,
        { body: { email: "integration-probe@serveaso.test" } }
      );
      if (status === 200 || status === 400 || status === 404) {
        return { ok: true };
      }
      return { ok: false, detail: `check-email probe status ${status}` };
    });
  });

  it("payments GET /ready when route exists", async (t) => {
    const { status, json } = await getReady("payments", serviceUrls.payments);
    if (status === 404) {
      return t.skip("payments /ready not deployed yet — redeploy payments for OPS-1");
    }
    assert.equal(status, 200);
    assert.equal(json?.status, "ready");
    assert.equal(json?.service, "payments");
  });
});
