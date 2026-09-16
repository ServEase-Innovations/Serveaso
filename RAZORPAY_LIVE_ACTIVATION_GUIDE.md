# Razorpay Live Activation Guide - Accept Real Payments

## 🎯 Overview

This guide will help you transition from Razorpay **Test Mode** to **Live Mode** to accept real payments.

---

## ⚠️ CRITICAL: Before You Start

### ✅ Prerequisites Checklist

- [ ] Your app is fully tested with test payments
- [ ] All payment flows work correctly
- [ ] Refund/cancellation flows are tested
- [ ] Webhook is configured and working
- [ ] You have a registered business
- [ ] You have all KYC documents ready

### 📋 Documents Required

1. **Business Documents:**
   - PAN Card (Company/Proprietor)
   - GST Certificate (if applicable)
   - Certificate of Incorporation / Partnership Deed
   - Cancelled cheque or bank statement

2. **Personal Documents (Directors/Partners):**
   - PAN Card
   - Aadhaar Card
   - Address Proof

3. **Bank Details:**
   - Bank account number
   - IFSC code
   - Account holder name (must match business name)

---

## Step 1: Activate Razorpay Account (24-48 hours)

### A. Submit KYC

1. **Login to Razorpay Dashboard:**
   ```
   https://dashboard.razorpay.com
   ```

2. **Navigate to Activation:**
   ```
   Dashboard → Settings → Account & Settings → Activation
   ```
   Or click the banner: **"Activate your account to accept payments"**

3. **Fill Business Details:**
   - Business Name: `ServEase Innovations` (or your registered name)
   - Business Type: Select (Proprietorship/Partnership/Pvt Ltd/LLP)
   - Business Category: `Service Provider Platform`
   - Business Subcategory: `Home Services`
   - Website URL: `https://serveaso.com`
   - Business PAN
   - GST Number (if applicable)

4. **Fill Personal Details:**
   - Director/Owner name
   - PAN number
   - Aadhaar number
   - Date of birth
   - Residential address

5. **Bank Account Details:**
   - Account holder name (must match business name)
   - Account number
   - IFSC code
   - Upload cancelled cheque or bank statement

6. **Upload Documents:**
   - Click "Upload" for each document type
   - Ensure clear, readable images
   - File size: < 5MB each
   - Formats: PDF, JPG, PNG

7. **Submit for Review:**
   - Review all details
   - Click **"Submit for Activation"**
   - Wait for email confirmation

### B. Activation Timeline

| Step | Time | Status Check |
|------|------|--------------|
| Document submission | Immediate | Dashboard shows "Under Review" |
| Initial review | 2-4 hours | Email notification |
| Detailed verification | 24-48 hours | Dashboard updates |
| Approval | - | Email: "Account Activated" |

### C. Common Rejection Reasons

❌ **Avoid these issues:**
- Mismatched names (Business name ≠ Bank account name)
- Blurry/incomplete documents
- Unregistered business
- Invalid PAN/GST numbers
- High-risk business category without proper documents

---

## Step 2: Generate Live API Keys

Once activated (you'll receive email):

1. **Switch to Live Mode:**
   - Dashboard top-right: Toggle **"Test Mode" → "Live Mode"**
   - Page background changes color

2. **Navigate to API Keys:**
   ```
   Settings → API Keys (or Security & API)
   ```

3. **Generate Live Keys:**
   - Click **"Generate Key"** or **"Regenerate"**
   - You'll see:
     ```
     Key ID: rzp_live_xxxxxxxxxxxxx
     Key Secret: xxxxxxxxxxxxxxxxxxxxx
     ```

4. **⚠️ IMPORTANT - Save Immediately:**
   - **Copy both keys NOW**
   - Key Secret is shown **only once**
   - If lost, you must regenerate (invalidates old key)
   - Store in password manager or secure vault

---

## Step 3: Configure Live Webhooks

1. **In Live Mode, go to Webhooks:**
   ```
   Settings → Webhooks → Add New Webhook
   ```

2. **Webhook URL:**
   ```
   https://payments-2z09.onrender.com/api/v2/createEngagements/webhook
   ```

3. **Active Events:**
   - ✅ `payment.captured`
   - (Optional: select all)

4. **Secret:**
   - Let Razorpay auto-generate
   - **Copy the webhook secret** (shown only once)
   - Format: `whsec_xxxxxxxxxxxxx`

5. **Alert Email:**
   - Add your email for failure alerts

6. **Save Webhook**

---

## Step 4: Update Production Environment

### A. Update Render.com (Backend)

1. **Go to Render Dashboard:**
   ```
   https://dashboard.render.com
   ```

2. **Update Payments Service:**
   - Select: `serveaso-payments` service
   - Go to: **Environment** tab
   - Update/Add:
     ```
     RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxxx
     RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxxxxxxx
     RAZORPAY_KEY=rzp_live_xxxxxxxxxxxxx
     RAZORPAY_SECRET=xxxxxxxxxxxxxxxxxxxxx
     RAZORPAY_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx
     ```
   - Click **"Save Changes"**
   - Wait for auto-redeploy (~2-3 min)

### B. Update Frontend Apps on Render

1. **For iOS App Deployment:**
   - Update environment variable:
     ```
     REACT_APP_RAZORPAY_KEY=rzp_live_xxxxxxxxxxxxx
     ```

2. **For Web UI Deployment:**
   - Update environment variable:
     ```
     REACT_APP_RAZORPAY_KEY=rzp_live_xxxxxxxxxxxxx
     ```

3. **Redeploy both apps**

---

## Step 5: Test Live Payments (Small Amount)

### Before Going Fully Live:

1. **Make a test payment with real money:**
   - Use ₹1 or ₹10
   - Use your own card
   - Complete the full payment flow

2. **Verify Everything:**
   - ✅ Payment appears in Razorpay Live dashboard
   - ✅ Order status updates in your database
   - ✅ Webhook is delivered successfully
   - ✅ Customer receives confirmation
   - ✅ Service provider is notified

3. **Test Refund:**
   - Initiate refund from dashboard
   - Verify refund is processed
   - Check database status updates

4. **If all successful:**
   - ✅ You're ready to accept real payments!

---

## Security Checklist for Live Mode

### ✅ Environment Variables

- [ ] Live keys are **NOT** in code (only in environment)
- [ ] `.env.production.local` is in `.gitignore`
- [ ] No live keys in git history
- [ ] Render environment variables are set correctly
- [ ] Webhook secret is configured

### ✅ Validation

- [ ] Signature verification is **ENABLED**
- [ ] `SKIP_RAZORPAY_VERIFY` is **NOT** set to true
- [ ] `SKIP_RAZORPAY_WEBHOOK_VERIFY` is **NOT** set to true
- [ ] Production secrets validation is active

### ✅ Error Handling

- [ ] Payment failures are handled gracefully
- [ ] Duplicate payments are prevented
- [ ] Refunds work correctly
- [ ] Error messages are user-friendly

### ✅ Monitoring

- [ ] Set up Razorpay webhook alerts
- [ ] Monitor payment failure rates
- [ ] Set up database backup
- [ ] Enable application logging

---

## Local Testing with Live Keys (Optional)

⚠️ **NOT RECOMMENDED** - Only for final integration testing

If you must test locally with live keys:

1. **Created files for you:**
   - `services/payments/.env.production.local`
   - `apps/servease-ios/.env.production.local`

2. **Add your live keys to these files**

3. **Run with production config:**
   ```bash
   # Backend
   cd services/payments
   NODE_ENV=production npm start

   # iOS
   cd apps/servease-ios
   REACT_APP_ENV=production npm run ios
   ```

4. **⚠️ CAUTION:**
   - Real money will be charged
   - Use small amounts only (₹1-10)
   - Never commit these files

---

## Razorpay Fees

Understand the costs:

### Transaction Fees (Domestic)

| Payment Method | Fee |
|----------------|-----|
| Debit Card | 2% (No setup/annual fees) |
| Credit Card | 2% |
| UPI | FREE up to ₹2000, then 2% |
| Net Banking | ₹10 per transaction |
| Wallet | 2% |

### Refunds

- Razorpay fees are **NOT** refunded
- Example: ₹100 payment → ₹2 fee → Refund ₹100 → You lose ₹2

### Settlement

- Payments settled to your bank: T+3 days (3 working days)
- Instant settlements available (additional fee)

---

## Monitoring & Analytics

### Razorpay Dashboard

Monitor these metrics:

1. **Payments:**
   - Live → Transactions → Payments
   - Success rate (should be > 95%)
   - Average transaction value
   - Peak hours

2. **Webhooks:**
   - Live → Webhooks → Event Logs
   - Delivery success rate (should be 100%)
   - Failed deliveries (investigate immediately)

3. **Disputes:**
   - Live → Disputes
   - Respond within 7 days
   - Provide proof of service delivery

4. **Settlements:**
   - Live → Settlements
   - Verify bank account receives funds
   - Check for any holds/deductions

---

## Common Issues & Solutions

### Issue 1: Payment succeeds but order not updated

**Cause:** Webhook not delivered or signature mismatch

**Solution:**
1. Check webhook logs in Razorpay
2. Verify `RAZORPAY_WEBHOOK_SECRET` matches dashboard
3. Check backend logs for errors
4. Manually verify payment using `/verify` endpoint

---

### Issue 2: "Invalid key_id" error

**Cause:** Wrong key or not in correct mode

**Solution:**
1. Verify you're in Live Mode (dashboard)
2. Check key starts with `rzp_live_`
3. Verify key is correct in environment variables
4. Redeploy service after updating

---

### Issue 3: Account suddenly suspended

**Cause:** Violation of terms or suspicious activity

**Solution:**
1. Check email from Razorpay
2. Contact support immediately
3. Provide requested documents
4. Common reasons:
   - High chargeback rate
   - Fake/test transactions in live mode
   - Unusual transaction patterns

---

## Support & Resources

### Razorpay Support

- **Email:** support@razorpay.com
- **Phone:** 1800-102-0808
- **Dashboard:** Help button (bottom-right)
- **Docs:** https://razorpay.com/docs/

### Your Account Manager

After going live, you'll be assigned an account manager for:
- Technical support
- Business queries
- Settlement issues
- Feature requests

---

## Final Checklist Before Going Live

- [ ] Razorpay account activated (received email)
- [ ] Live API keys generated and saved securely
- [ ] Webhook configured in Live mode
- [ ] Environment variables updated on Render
- [ ] All services redeployed
- [ ] Test payment with ₹1 completed successfully
- [ ] Payment appears in Live dashboard
- [ ] Webhook delivered successfully
- [ ] Database updated correctly
- [ ] Refund tested and working
- [ ] Error handling tested
- [ ] Monitoring/alerts configured
- [ ] Team knows how to handle payment issues
- [ ] Customer support ready for payment queries

---

## 🎉 You're Live!

Once all checks pass, you're ready to accept real payments!

### Monitor First Few Days:

- Watch payment success rate
- Check webhook delivery rate
- Monitor customer complaints
- Verify settlements arrive
- Check for any errors in logs

### Need Help?

Refer to:
- This guide: `RAZORPAY_LIVE_ACTIVATION_GUIDE.md`
- Webhook setup: `RAZORPAY_WEBHOOK_SETUP.md`
- Quick reference: `RAZORPAY_WEBHOOK_QUICK_SETUP.md`

---

**Last Updated:** August 16, 2026
**Status:** Ready for activation
