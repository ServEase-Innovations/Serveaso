# Razorpay Webhook Setup Guide

## Overview

Razorpay webhooks are **already implemented** in the payments service. This guide shows you how to enable them in your Razorpay dashboard.

## Why Use Webhooks?

Webhooks provide automatic payment confirmation without requiring the customer to manually verify. Benefits:
- **Faster payment confirmation** - Razorpay notifies your server immediately when payment succeeds
- **Better reliability** - Works even if the customer closes the browser/app after payment
- **Automatic updates** - No need for manual verification API calls

---

## Current Implementation

### Webhook Endpoints

Your payments service has these webhook endpoints ready:

1. **Primary (V2):**
   ```
   POST https://payments-lx25.onrender.com/api/v2/createEngagements/webhook
   ```

2. **Alternate:**
   ```
   POST https://payments-lx25.onrender.com/api/v2/webhooks/webhook
   ```

### Supported Events

Currently handles:
- ✅ `payment.captured` - Payment successfully captured by Razorpay

Other events are safely ignored (return 200 OK).

---

## Step-by-Step Setup

### 1. Get Your Webhook Secret

After creating the webhook in Razorpay (Step 2), you'll receive a **Webhook Secret**. It looks like:
```
whsec_AbCd1234EfGh5678IjKl9012MnOp3456
```

### 2. Configure Razorpay Dashboard

1. **Login to Razorpay Dashboard:**
   - Test Mode: https://dashboard.razorpay.com/app/webhooks (for development)
   - Live Mode: Switch to live mode first, then go to webhooks

2. **Create New Webhook:**
   - Click **"+ New Webhook"** or **"Add Webhook"**

3. **Enter Webhook URL:**
   ```
   https://payments-lx25.onrender.com/api/v2/createEngagements/webhook
   ```

4. **Select Events:**
   - ✅ Check: `payment.captured`
   - (Optional) You can select all events; only `payment.captured` will be processed

5. **Enter a Secret (Optional but Recommended):**
   - Razorpay will auto-generate one if you leave it blank
   - **Copy this secret** - you'll need it for environment variables

6. **Alert Email:**
   - Add your email to receive webhook failure alerts

7. **Click "Create Webhook"**

8. **Copy the Webhook Secret:**
   - After creation, copy the webhook secret shown
   - Example: `whsec_AbCd1234EfGh5678IjKl9012MnOp3456`

### 3. Add Webhook Secret to Environment Variables

Add the webhook secret to your deployment environment:

#### **On Render.com (Production):**

1. Go to your **payments service** in Render dashboard
2. Navigate to **Environment** tab
3. Add new environment variable:
   ```
   RAZORPAY_WEBHOOK_SECRET=whsec_AbCd1234EfGh5678IjKl9012MnOp3456
   ```
4. Click **"Save Changes"**
5. Service will auto-redeploy

#### **Local Development:**

Add to `services/payments/.env.development`:
```bash
RAZORPAY_WEBHOOK_SECRET=whsec_AbCd1234EfGh5678IjKl9012MnOp3456
```

---

## Testing Webhooks

### Test in Razorpay Dashboard

1. Go to **Webhooks** section
2. Click on your webhook
3. Click **"Send Test Webhook"**
4. Select event: `payment.captured`
5. Check the response - should return `200 OK`

### Test with Real Payment (Test Mode)

1. Make a test payment using test card:
   - Card: `4111 1111 1111 1111`
   - CVV: Any 3 digits
   - Expiry: Any future date

2. Check your server logs:
   ```bash
   # Should see:
   Razorpay webhook received: payment.captured
   Payment SUCCESS: engagement_id=123
   ```

3. Verify in database:
   - Payment status should be `SUCCESS`
   - Engagement status should transition to `ASSIGNED` or next state

### Check Webhook Logs in Razorpay

1. Go to **Webhooks** in dashboard
2. Click on your webhook
3. View **"Event Logs"** tab
4. See delivery status:
   - ✅ Green: Successfully delivered (200 response)
   - ❌ Red: Failed delivery

---

## Environment Variables

### Required Variables

```bash
# Razorpay API Credentials
RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxxx         # Live key
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxx              # Live secret

# Webhook Security
RAZORPAY_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxxxxx # From Razorpay dashboard
```

### Development Variables (Optional)

```bash
# Skip webhook verification in development (NOT RECOMMENDED)
SKIP_RAZORPAY_WEBHOOK_VERIFY=true              # Only for local testing
```

⚠️ **Warning:** Never set `SKIP_RAZORPAY_WEBHOOK_VERIFY=true` in production!

---

## Security Features

Your webhook implementation includes:

### ✅ HMAC Signature Verification
- All webhook requests are verified using `x-razorpay-signature` header
- Uses SHA-256 HMAC with your webhook secret
- Prevents unauthorized webhook calls

### ✅ Raw Body Preservation
- Request body is preserved for signature verification
- Middleware in `services/payments/index.js` handles this

### ✅ Production Validation
- `validateProductionSecrets.js` enforces:
  - `RAZORPAY_WEBHOOK_SECRET` must be set in production
  - `SKIP_RAZORPAY_WEBHOOK_VERIFY` cannot be true in production

### ✅ Idempotent Processing
- Duplicate webhook calls are safely ignored
- Payment state is checked before processing

---

## Troubleshooting

### Webhook Returns 400: "Invalid signature"

**Cause:** Webhook secret mismatch

**Fix:**
1. Check `RAZORPAY_WEBHOOK_SECRET` in your environment
2. Verify it matches the secret in Razorpay dashboard
3. Redeploy service after updating

### Webhook Returns 503: "Webhook verification is not configured"

**Cause:** `RAZORPAY_WEBHOOK_SECRET` environment variable not set

**Fix:**
1. Add `RAZORPAY_WEBHOOK_SECRET` to your environment
2. Get the secret from Razorpay dashboard → Webhooks → Your Webhook
3. Redeploy service

### Webhook Returns 404: "Payment / engagement not found"

**Cause:** Order ID in webhook doesn't match any payment record

**Fix:**
1. Check if payment was created successfully in database
2. Verify `razorpay_order_id` in payments table
3. Check engagement notes for `engagementId` or `engagement_id`

### Webhooks Not Being Delivered

**Check:**
1. **Webhook URL is publicly accessible:**
   ```bash
   curl https://payments-lx25.onrender.com/api/v2/createEngagements/webhook
   # Should return 400 (not 404)
   ```

2. **Service is running:**
   - Check Render dashboard for service status
   - Check logs for startup errors

3. **Razorpay Event Logs:**
   - Go to Webhooks → Your Webhook → Event Logs
   - Check delivery attempts and responses

### Local Development with ngrok

To test webhooks locally:

1. **Install ngrok:**
   ```bash
   brew install ngrok
   ```

2. **Start your local payments service:**
   ```bash
   cd services/payments
   npm start
   # Running on http://localhost:5003
   ```

3. **Create ngrok tunnel:**
   ```bash
   ngrok http 5003
   ```

4. **Copy ngrok URL:**
   ```
   Forwarding: https://abc123.ngrok.io -> http://localhost:5003
   ```

5. **Update Razorpay webhook URL:**
   ```
   https://abc123.ngrok.io/api/v2/createEngagements/webhook
   ```

6. **Set local environment:**
   ```bash
   SKIP_RAZORPAY_WEBHOOK_VERIFY=true  # For local testing only
   ```

---

## Code References

### Webhook Handler
- **File:** `services/payments/src/services/razorpayWebhook.service.js`
- **Function:** `handleRazorpayPaymentWebhook(req, res)`

### Signature Verification
- **File:** `services/payments/src/utils/razorpayWebhookHmac.js`
- **Function:** `verifyRazorpayWebhookSignature(rawBody, signature, webhookSecret)`

### Routes
- **File:** `services/payments/src/routes/v2/createEngagements.js`
- **Route:** `POST /api/v2/createEngagements/webhook`

### Middleware
- **File:** `services/payments/index.js`
- **Purpose:** Preserves raw request body for signature verification

---

## Webhook Flow

```
┌─────────────────┐
│   Customer      │
│  Pays via App   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Razorpay      │
│ Processes Card  │
└────────┬────────┘
         │
         ├──────────────────────────────────┐
         │                                  │
         ▼                                  ▼
┌─────────────────┐              ┌──────────────────┐
│   Customer      │              │  Your Server     │
│  Redirected     │              │  Webhook Called  │
│  Back to App    │              │  (Automatic)     │
└────────┬────────┘              └────────┬─────────┘
         │                                │
         ▼                                ▼
┌─────────────────┐              ┌──────────────────┐
│   App Calls     │              │  Verify HMAC     │
│  /verify API    │              │  Signature       │
└────────┬────────┘              └────────┬─────────┘
         │                                │
         └────────────┬───────────────────┘
                      ▼
              ┌──────────────────┐
              │  handlePayment   │
              │  Success()       │
              │  (Idempotent)    │
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │  Update Payment  │
              │  Status SUCCESS  │
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │  Update          │
              │  Engagement      │
              │  Status          │
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │  Send Socket     │
              │  Notifications   │
              └──────────────────┘
```

---

## Best Practices

### ✅ DO:
- Use webhooks for automatic payment confirmation
- Keep webhook secret secure (never commit to git)
- Monitor webhook delivery logs in Razorpay dashboard
- Set up alert emails for webhook failures
- Test webhooks in test mode before going live

### ❌ DON'T:
- Don't skip signature verification in production
- Don't use test keys in live mode
- Don't expose webhook endpoints without authentication
- Don't rely only on webhooks (keep /verify endpoint as fallback)
- Don't log full webhook payloads (may contain sensitive data)

---

## Support

- **Razorpay Docs:** https://razorpay.com/docs/webhooks/
- **Dashboard:** https://dashboard.razorpay.com/app/webhooks
- **Support:** support@razorpay.com

---

## Checklist

- [ ] Created webhook in Razorpay dashboard
- [ ] Selected `payment.captured` event
- [ ] Copied webhook secret
- [ ] Added `RAZORPAY_WEBHOOK_SECRET` to Render environment
- [ ] Redeployed payments service
- [ ] Tested webhook with test payment
- [ ] Verified webhook logs show successful delivery
- [ ] Checked payment status updates correctly
- [ ] Set up alert email in Razorpay
- [ ] Documented webhook URL for team

---

**Last Updated:** August 16, 2026
