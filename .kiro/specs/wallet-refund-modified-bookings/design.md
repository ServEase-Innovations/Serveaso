# Design: Wallet Refund Bug Fix for Modified Bookings

## Bug Summary

**Issue:** When users cancel a booking that was previously modified (schedule change), the refundable amount is not credited to their wallet.

**Root Cause:** The cancellation logic fetches the LATEST payment record (modification fee payment with no refundable amount) instead of the ORIGINAL booking payment (which has the actual refundable amount).

**Impact:** Users who modify and then cancel bookings lose their entitled refund, leading to financial loss and customer dissatisfaction.

---

## Technical Analysis

### Current Broken Flow

1. **User creates booking:**
   - Payment record #1 created: `{ base_amount: 1500, wallet_amount: 200, razorpay_amount: 1300, status: SUCCESS }`
   - Wallet deducted: ₹200

2. **User modifies booking schedule:**
   - Payment record #2 created: `{ base_amount: 0, platform_fee: 90, gst: 0, wallet_amount: 0, status: SUCCESS }`
   - This is the modification fee payment

3. **User cancels booking:**
   - Cancellation endpoint queries: `SELECT * FROM payments WHERE engagement_id = $1 ORDER BY payment_id DESC LIMIT 1`
   - **Returns payment #2** (modification fee payment)
   - `computeBookingRefundBreakdown(payment #2)` calculates:
     - `total = 0` (no base_amount in modification payment)
     - `walletRefund = 0` (no wallet_amount in modification payment)
     - `razorpayRefund = 0`
   - **Result:** No wallet credit, no refund ❌

### Expected Correct Flow

1. **User creates booking:** (same as above)
2. **User modifies booking:** (same as above)
3. **User cancels booking:**
   - Cancellation should identify the **original booking payment** (payment #1)
   - `computeBookingRefundBreakdown(payment #1)` calculates:
     - `total = 1500`
     - `walletRefund = 200` (min of wallet_amount and total)
     - `razorpayRefund = 1300`
   - Wallet credited: ₹200 ✅
   - Razorpay refund initiated: ₹1300 ✅

---

## Solution Design

### Approach: Filter for Original Booking Payment

Instead of fetching the latest payment blindly, we need to identify the **original booking payment** by filtering out modification fee payments.

**Distinguishing Characteristics:**
- **Original booking payment:** `base_amount > 0`, `platform_fee >= 0`, `gst >= 0`
- **Modification fee payment:** `base_amount = 0`, `platform_fee > 0`, `gst = 0`

### Code Changes Required

#### 1. Update Cancellation Endpoint Query

**File:** `services/payments/src/routes/v2/engagementsV2.js`

**Current query (line 216-221):**
```javascript
const paymentRes = await client.query(
  `SELECT payment_id, engagement_id, total_amount, wallet_amount, 
          wallet_deducted, transaction_id, status, payment_mode
   FROM payments
   WHERE engagement_id = $1
   ORDER BY payment_id DESC
   LIMIT 1`,
  [id]
);
```

**Fixed query:**
```javascript
const paymentRes = await client.query(
  `SELECT payment_id, engagement_id, total_amount, wallet_amount, 
          wallet_deducted, transaction_id, status, payment_mode, base_amount
   FROM payments
   WHERE engagement_id = $1
     AND COALESCE(base_amount, 0) > 0
   ORDER BY payment_id ASC
   LIMIT 1`,
  [id]
);
```

**Changes:**
1. Added `base_amount` to SELECT (needed for refund calculation)
2. Added filter: `AND COALESCE(base_amount, 0) > 0` (excludes modification fee payments)
3. Changed sort order: `ASC` instead of `DESC` (gets first/original booking payment)

**Why this works:**
- Modification fee payments have `base_amount = 0` or NULL
- Original booking payments always have `base_amount > 0`
- This ensures we refund based on the actual booking payment, not the modification fee

---

#### 2. Add Similar Fix to Other Cancellation Endpoints (if any)

We need to check if there are other cancellation flows that might have the same issue:

**Files to check:**
- `services/payments/src/routes/engagements.js` (legacy engagements endpoint)
- `services/payments/src/services/onDemandUnassignedCancel.service.js` (auto-cancel flow)

**Search pattern:** Look for cancellation logic that fetches payments and calls refund functions.

---

## Edge Cases to Handle

### 1. Multiple Modifications

**Scenario:** User modifies booking 3 times, then cancels
- Payment records: [original, mod1, mod2, mod3]
- Solution: `base_amount > 0` filter + `ORDER BY ASC LIMIT 1` always gets the original
- **Status:** ✅ Handled

### 2. Partial Refunds (Future Feature)

**Scenario:** User consumes part of service, then cancels
- May need to calculate refund based on days remaining
- Solution: Pro-rated refund should still use original payment as base
- **Status:** ✅ Compatible with future enhancement

### 3. Booking Extended, Then Cancelled

**Scenario:** User extends booking (pays additional), then cancels
- Extension creates a separate payment record with `base_amount > 0`
- Current solution would refund only the original booking
- **Consideration:** Extension refunds may need separate handling
- **Status:** ⚠️ Requires investigation (separate task)

### 4. Wallet Top-up Between Booking and Cancellation

**Scenario:** Original payment used ₹200 wallet, user tops up ₹500, then cancels
- Refund should credit ₹200 (the amount originally used)
- Solution: We refund based on `payment.wallet_amount`, not current balance
- **Status:** ✅ Handled (no changes needed)

### 5. No Original Payment Found

**Scenario:** Booking created but payment failed, then somehow cancelled
- Query returns empty result
- Current code handles this: "No payment found for engagement"
- **Status:** ✅ Already handled

---

## Testing Strategy

### Unit Tests

**File:** `services/payments/src/routes/v2/__tests__/engagementsV2.test.js`

Test cases:
1. ✅ Cancel unmodified booking → refund processed correctly
2. ✅ Cancel modified booking (1 modification) → refund uses original payment
3. ✅ Cancel modified booking (multiple modifications) → refund uses original payment
4. ✅ Cancel booking with no payment → handled gracefully
5. ✅ Cancel booking where original payment failed → no refund

### Integration Tests

**Scenario:** Full user journey
1. Create booking with Razorpay + wallet (₹200 wallet, ₹1300 Razorpay)
2. Modify booking schedule (pay ₹90 modification fee)
3. Cancel booking
4. **Assert:**
   - Wallet credited: ₹200 ✅
   - Wallet transaction record created ✅
   - Razorpay refund initiated: ₹1300 ✅
   - Payment status updated to REFUNDED ✅

### Manual Testing Checklist

- [ ] Create ON_DEMAND booking with wallet + Razorpay
- [ ] Modify schedule → pay modification fee
- [ ] Cancel booking
- [ ] Verify wallet balance increased by original wallet amount
- [ ] Verify wallet transaction entry shows "Refund for cancelled booking #X"
- [ ] Verify Razorpay refund initiated for original Razorpay amount
- [ ] Check database: payment status = REFUNDED
- [ ] Check engagement_events: ENGAGEMENT_CANCELLED with correct refund metadata

---

## Rollout Plan

### Phase 1: Fix and Test (This Spec)
- Update cancellation query in `engagementsV2.js`
- Add unit tests
- Manual testing on staging

### Phase 2: Audit Other Endpoints (Follow-up)
- Check legacy `engagements.js` endpoint
- Check auto-cancel flow
- Apply same fix if needed

### Phase 3: Database Audit (Optional)
- Query to find affected users:
```sql
SELECT 
  e.engagement_id,
  e.customerid,
  e.engagement_status,
  COUNT(p.payment_id) as payment_count,
  MAX(CASE WHEN p.base_amount > 0 THEN p.total_amount ELSE 0 END) as original_amount
FROM engagements e
JOIN payments p ON p.engagement_id = e.engagement_id AND p.status = 'SUCCESS'
JOIN engagement_modifications em ON em.engagement_id = e.engagement_id
WHERE e.engagement_status = 'CANCELLED'
  AND e.updated_at > '2024-01-01'
GROUP BY e.engagement_id, e.customerid, e.engagement_status
HAVING COUNT(p.payment_id) > 1;
```

- Manual review and compensation for affected users (if applicable)

---

## Success Criteria

1. ✅ Users who modify and then cancel bookings receive wallet refunds
2. ✅ Refund amount matches the original booking payment (wallet + Razorpay portions)
3. ✅ Wallet transaction records are created correctly
4. ✅ No regression in unmodified booking cancellations
5. ✅ All automated tests pass
6. ✅ Manual testing confirms end-to-end flow works

---

## Related Files

### Files to Modify
- `services/payments/src/routes/v2/engagementsV2.js` (main fix)

### Files to Review (potential similar issues)
- `services/payments/src/routes/engagements.js`
- `services/payments/src/services/onDemandUnassignedCancel.service.js`

### Reference Files (no changes needed)
- `services/payments/src/services/bookingPaymentRefund.service.js` (refund logic - works correctly)
- `services/payments/src/services/customerWallet.service.js` (wallet credit logic - works correctly)
- `services/payments/src/services/scheduleModification.service.js` (modification flow - creates separate payment)

---

## Notes

- This is a **critical bug** affecting user refunds (financial impact)
- The fix is **minimal and safe** (just changes the payment selection query)
- The refund calculation logic itself is correct (no changes needed there)
- Extension refunds may need separate investigation (different payment pattern)
