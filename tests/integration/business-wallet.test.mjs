import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { serviceUrls, getTestCustomerId } from "./lib/config.mjs";
import { httpJson } from "./lib/http.mjs";
import { internalAuthHeaders } from "./lib/auth.mjs";

describe("Customer Wallet (payments)", () => {
  const customerId = getTestCustomerId();
  const walletUrl = `${serviceUrls.payments}/api/wallets/${customerId}`;

  it("GET /api/wallets/:customerId returns balance and transactions", async () => {
    const { status, json } = await httpJson("GET", walletUrl, {
      headers: internalAuthHeaders(),
    });

    assert.equal(status, 200, `Expected 200, got ${status}: ${JSON.stringify(json)}`);
    assert.ok(json?.balance !== undefined);
    assert.ok(Array.isArray(json?.transactions));
  });

  it("POST /api/wallets/:customerId/topup creates a pending Razorpay order", async () => {
    const topupAmount = 500;
    const { status, json } = await httpJson("POST", `${walletUrl}/topup`, {
      headers: internalAuthHeaders(),
      body: {
        amount: topupAmount,
      },
    });

    assert.equal(status, 201, `Expected 201, got ${status}: ${JSON.stringify(json)}`);
    assert.equal(json?.success, true);
    assert.ok(json?.razorpay_order_id);
    assert.equal(json?.amount, topupAmount * 100); // Razorpay amount is in paise
    assert.equal(json?.currency, "INR");
    assert.ok(json?.topup_id);
  });

});
