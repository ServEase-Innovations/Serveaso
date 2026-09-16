# Razorpay Webhook - Quick Setup (5 Minutes)

## ✅ Good News: Webhooks Are Already Implemented!

Your code is ready. You just need to configure Razorpay dashboard.

---

## Step 1: Login to Razorpay Dashboard

**Test Mode:** https://dashboard.razorpay.com/app/webhooks

*(For production: Switch to "Live Mode" first)*

---

## Step 2: Create Webhook

1. Click **"+ Add New Webhook"**

2. **Webhook URL:**
   ```
   https://payments-lx25.onrender.com/api/v2/createEngagements/webhook
   ```

3. **Active Events:** Select `payment.captured`

4. **Secret:** Leave blank (auto-generated) or create your own

5. Click **"Create Webhook"**

6. **Copy the Webhook Secret** (looks like: `whsec_xxxxxx`)

---

## Step 3: Add Secret to Render

1. Go to: https://dashboard.render.com

2. Open your **payments service**

3. Go to **Environment** tab

4. Add variable:
   ```
   RAZORPAY_WEBHOOK_SECRET = whsec_your_secret_here
   ```

5. Click **Save Changes** (auto-redeploys)

---

## Step 4: Test It

### Option A: Test in Dashboard
1. Go to Razorpay → Webhooks → Your Webhook
2. Click **"Send Test Webhook"**
3. Select: `payment.captured`
4. Should return: **200 OK** ✅

### Option B: Make Test Payment
1. Use test card: `4111 1111 1111 1111`
2. Payment should auto-confirm via webhook
3. Check: Razorpay → Webhooks → Event Logs → Should show ✅

---

## Current Setup

**Development:**
- ✅ Webhook secret already in `.env.development`: `Serveaso@1234`
- ✅ Code is working locally

**Production:**
- ⚠️ Need to add `RAZORPAY_WEBHOOK_SECRET` to Render environment

---

## Webhook Endpoints

Primary:
```
POST /api/v2/createEngagements/webhook
```

Alternate:
```
POST /api/v2/webhooks/webhook
```

Both work identically.

---

## What Happens When Enabled?

**Before (Manual):**
```
Customer pays → Redirected to app → App calls /verify → Status updated
```

**After (Automatic):**
```
Customer pays → Razorpay sends webhook → Status updated automatically
                ↓
            Redirected to app (status already updated!)
```

**Benefits:**
- ⚡ Faster confirmation
- 🛡️ Works even if customer closes app
- 🔄 More reliable

---

## Troubleshooting

### "Invalid signature" error?
- Webhook secret mismatch
- Update `RAZORPAY_WEBHOOK_SECRET` in Render
- Get correct secret from Razorpay dashboard

### "Webhook verification not configured"?
- `RAZORPAY_WEBHOOK_SECRET` not set
- Add it to Render environment variables

### Not receiving webhooks?
1. Check service is running
2. Test URL: `curl https://payments-lx25.onrender.com/api/v2/createEngagements/webhook`
3. Check Razorpay → Webhooks → Event Logs

---

## For Full Details

See: `RAZORPAY_WEBHOOK_SETUP.md`

---

**Setup Time:** 5 minutes  
**Status:** Code ready, just needs dashboard configuration  
**Priority:** High (improves reliability)
