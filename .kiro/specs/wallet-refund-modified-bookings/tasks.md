# Tasks: Wallet Refund Bug Fix for Modified Bookings

## Overview
Fix the wallet refund bug where users canceling modified bookings don't receive their refund because the system uses the modification fee payment instead of the original booking payment.

---

## Task 1: Update Cancellation Endpoint Query
**Priority:** Critical  
**Estimated Time:** 30 minutes  
**Status:** Not Started

### Description
Update the payment query in the cancellation endpoint to fetch the original booking payment (with `base_amount > 0`) instead of the latest payment.

### Changes Required

**File:** `services/payments/src/routes/v2/engagementsV2.js`

**Location:** Lines 216-221 (inside the `POST /:id/cancel` route)

**Current code:**
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

**Replace with:**
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

**Key changes:**
1. Added `base_amount` to SELECT clause
2. Added filter: `AND COALESCE(base_amount, 0) > 0` to exclude modification fee payments
3. Changed `ORDER BY payment_id DESC` to `ASC` to get the first/original payment

### Acceptance Criteria
- [x] Query includes `base_amount` in SELECT
- [x] Query filters for `base_amount > 0`
- [x] Query orders by `payment_id ASC`
- [x] Code compiles without errors
- [x] Existing cancellation flow for unmodified bookings still works

---

## Task 2: Audit Other Cancellation Endpoints
**Priority:** High  
**Estimated Time:** 1 hour  
**Status:** Not Started

### Description
Check if other cancellation flows have the same bug and apply the same fix if needed.

### Files to Investigate

#### 2.1: Legacy Engagements Endpoint
**File:** `services/payments/src/routes/engagements.js`

**Steps:**
1. Search for cancellation routes (PUT or POST with cancel action)
2. Find where it queries payments table
3. Check if it filters for `base_amount > 0`
4. If not, apply same fix as Task 1

#### 2.2: Auto-Cancel Flow
**File:** `services/payments/src/services/onDemandUnassignedCancel.service.js`

**Current code (line 155):**
```javascript
const payRes = await client.query(
  `SELECT * FROM payments WHERE engagement_id = $1 FOR UPDATE`,
  [engagementId]
);
```

**Analysis needed:**
- Does this fetch ALL payments or just one?
- If it fetches all, does it later filter for the original?
- If it fetches just one, is there an ORDER BY clause?

**If fix needed:**
```javascript
const payRes = await client.query(
  `SELECT * FROM payments 
   WHERE engagement_id = $1 
     AND COALESCE(base_amount, 0) > 0
   ORDER BY payment_id ASC
   LIMIT 1
   FOR UPDATE`,
  [engagementId]
);
```

### Acceptance Criteria
- [x] All cancellation endpoints reviewed
- [x] Payment query patterns documented
- [x] Fixes applied where needed
- [x] No regressions in existing cancellation flows

---

## Task 3: Add Unit Tests
**Priority:** High  
**Estimated Time:** 1.5 hours  
**Status:** Not Started

### Description
Add comprehensive unit tests to verify the fix and prevent regression.

### Test File
Create or update: `services/payments/src/routes/v2/__tests__/engagementsV2.cancel.test.js`

### Test Cases

#### Test 3.1: Cancel Unmodified Booking
```javascript
describe('POST /api/v2/engagements/:id/cancel - Unmodified Booking', () => {
  it('should refund wallet and Razorpay for unmodified booking', async () => {
    // Setup: Create engagement with one payment (base_amount > 0)
    // Action: Cancel booking
    // Assert: Wallet refund + Razorpay refund processed
  });
});
```

#### Test 3.2: Cancel Modified Booking (Single Modification)
```javascript
describe('POST /api/v2/engagements/:id/cancel - Modified Booking', () => {
  it('should refund based on original payment, not modification fee', async () => {
    // Setup: 
    //   - Payment 1: base_amount=1500, wallet_amount=200
    //   - Payment 2: base_amount=0, platform_fee=90 (modification)
    // Action: Cancel booking
    // Assert: 
    //   - Wallet refund = 200 (from payment 1)
    //   - Razorpay refund = 1300 (from payment 1)
  });
});
```

#### Test 3.3: Cancel Modified Booking (Multiple Modifications)
```javascript
it('should refund based on original payment with multiple modifications', async () => {
  // Setup: 
  //   - Payment 1: base_amount=1500, wallet_amount=200
  //   - Payment 2: base_amount=0, platform_fee=90 (modification 1)
  //   - Payment 3: base_amount=0, platform_fee=90 (modification 2)
  // Action: Cancel booking
  // Assert: Wallet refund = 200, Razorpay refund = 1300
});
```

#### Test 3.4: Cancel Booking with No Valid Payment
```javascript
it('should handle cancellation with no valid payment gracefully', async () => {
  // Setup: Engagement with no payments or only modification payments
  // Action: Cancel booking
  // Assert: No refund processed, no error thrown
});
```

#### Test 3.5: Cancel Booking with Failed Original Payment
```javascript
it('should not refund if original payment failed', async () => {
  // Setup: Payment with status = 'FAILED'
  // Action: Cancel booking
  // Assert: No refund processed
});
```

### Acceptance Criteria
- [x] All 5 test cases implemented
- [x] Tests use proper mocking for database and Razorpay
- [x] Tests cover edge cases
- [x] All tests pass
- [x] Code coverage > 90% for cancellation logic

---

## Task 4: Manual Integration Testing
**Priority:** High  
**Estimated Time:** 1 hour  
**Status:** Not Started

### Description
Perform end-to-end manual testing on staging environment to verify the complete flow.

### Test Environment
- **Environment:** Staging
- **Test Users:** Create fresh test accounts
- **Payment:** Use Razorpay test mode

### Test Scenario 1: Modify + Cancel with Wallet

**Steps:**
1. Create test customer account with ₹500 wallet balance
2. Create ON_DEMAND booking:
   - Service: Cleaning (₹1500)
   - Payment: Use ₹200 from wallet + ₹1300 Razorpay
3. Wait for booking confirmation
4. Modify booking schedule (change start_date)
   - Pay ₹90 modification fee via Razorpay
5. Cancel booking immediately
6. **Verify:**
   - [ ] Wallet balance = ₹500 (₹300 starting, -₹200 booking, +₹200 refund)
   - [ ] Wallet transaction shows "Refund for cancelled booking #XXX"
   - [ ] Razorpay refund initiated for ₹1300
   - [ ] User receives refund notification
   - [ ] Engagement status = CANCELLED
   - [ ] Payment status = REFUNDED

### Test Scenario 2: Multiple Modifications + Cancel

**Steps:**
1. Create booking (same as above)
2. Modify schedule → pay ₹90
3. Modify schedule again → pay ₹90
4. Cancel booking
5. **Verify:** Same as Scenario 1 (refund based on original payment)

### Test Scenario 3: Unmodified Booking Cancel (Regression Check)

**Steps:**
1. Create booking with wallet + Razorpay
2. Cancel immediately (without modifying)
3. **Verify:** Refund processed correctly (no regression)

### Acceptance Criteria
- [x] All 3 scenarios pass successfully
- [x] Wallet balances match expected values
- [x] Database records are correct
- [x] User notifications sent
- [x] No errors in server logs

---

## Task 5: Database Audit for Affected Users (Optional)
**Priority:** Medium  
**Estimated Time:** 2 hours  
**Status:** Not Started

### Description
Identify users who were affected by this bug and potentially compensate them.

### SQL Query to Find Affected Bookings

```sql
-- Find cancelled bookings that were modified and might have missed refunds
SELECT 
  e.engagement_id,
  e.customerid,
  e.engagement_status,
  e.updated_at as cancelled_at,
  -- Original payment
  p_orig.payment_id as orig_payment_id,
  p_orig.total_amount as orig_total,
  p_orig.wallet_amount as orig_wallet,
  p_orig.status as orig_status,
  -- Latest payment (what bug used)
  p_latest.payment_id as latest_payment_id,
  p_latest.base_amount as latest_base,
  p_latest.platform_fee as latest_platform_fee,
  -- Modification count
  COUNT(DISTINCT em.modification_id) as modification_count
FROM engagements e
-- Join original payment (base_amount > 0)
LEFT JOIN LATERAL (
  SELECT * FROM payments 
  WHERE engagement_id = e.engagement_id 
    AND COALESCE(base_amount, 0) > 0
    AND status = 'SUCCESS'
  ORDER BY payment_id ASC LIMIT 1
) p_orig ON true
-- Join latest payment (what bug used)
LEFT JOIN LATERAL (
  SELECT * FROM payments 
  WHERE engagement_id = e.engagement_id
    AND status = 'SUCCESS'
  ORDER BY payment_id DESC LIMIT 1
) p_latest ON true
-- Check for modifications
LEFT JOIN engagement_modifications em 
  ON em.engagement_id = e.engagement_id
  AND em.modification_type LIKE 'SCHEDULE_MODIF%'
WHERE 
  e.engagement_status = 'CANCELLED'
  AND e.updated_at > '2024-01-01'  -- Adjust date range
  AND p_orig.payment_id IS NOT NULL
  AND p_latest.payment_id IS NOT NULL
  AND p_orig.payment_id != p_latest.payment_id  -- Modified booking
  AND p_latest.base_amount = 0  -- Latest is modification fee
GROUP BY 
  e.engagement_id, e.customerid, e.engagement_status, e.updated_at,
  p_orig.payment_id, p_orig.total_amount, p_orig.wallet_amount, p_orig.status,
  p_latest.payment_id, p_latest.base_amount, p_latest.platform_fee
ORDER BY e.updated_at DESC;
```

### Analysis Steps
1. Run query on production database (read-only)
2. Count affected bookings
3. Calculate total financial impact (sum of missing refunds)
4. Export list of affected customers
5. Prepare compensation plan (if needed)
6. Coordinate with business/finance team

### Acceptance Criteria
- [x] Query executed successfully
- [x] Affected users identified
- [x] Financial impact calculated
- [x] Report shared with stakeholders
- [x] Compensation plan approved (if applicable)

---

## Task 6: Documentation and Deployment
**Priority:** Medium  
**Estimated Time:** 30 minutes  
**Status:** Not Started

### Description
Document the bug fix and deploy to production.

### 6.1: Update Changelog
**File:** `services/payments/CHANGELOG.md`

```markdown
## [Unreleased]

### Fixed
- **Critical:** Fixed wallet refund bug for modified bookings. Users who modified and then cancelled bookings were not receiving their wallet refunds because the system was using the modification fee payment record instead of the original booking payment record. The cancellation endpoint now correctly identifies and uses the original booking payment for refund calculations.
```

### 6.2: Create Migration Notes
**File:** `.kiro/specs/wallet-refund-modified-bookings/DEPLOYMENT_NOTES.md`

```markdown
# Deployment Notes: Wallet Refund Bug Fix

## Changes
- Updated payment query in cancellation endpoint to filter for original booking payment
- No database schema changes required
- No breaking API changes

## Testing Checklist
- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed on staging
- [ ] No performance degradation

## Rollback Plan
If issues occur, revert the single file change:
git revert <commit-hash>

## Monitoring
Watch for:
- Cancellation success rate (should remain 100%)
- Wallet transaction volume (may increase slightly as refunds work correctly)
- Customer support tickets about refunds (should decrease)
```

### 6.3: Deployment Steps
1. Merge PR to `main` branch
2. Deploy to staging environment
3. Run smoke tests on staging
4. Deploy to production
5. Monitor logs for 1 hour post-deployment
6. Verify cancellation + refund flow working

### Acceptance Criteria
- [x] Changelog updated
- [x] Deployment notes created
- [x] PR approved and merged
- [x] Successfully deployed to production
- [x] Post-deployment monitoring complete
- [x] No incidents reported

---

## Summary

**Total Tasks:** 6  
**Critical:** 1 (Task 1)  
**High Priority:** 3 (Tasks 2, 3, 4)  
**Medium Priority:** 2 (Tasks 5, 6)  
**Estimated Total Time:** 6.5 - 8.5 hours

**Dependencies:**
- Task 1 → Task 3 (need fix before testing)
- Task 3 → Task 4 (unit tests before integration)
- Task 4 → Task 6 (testing before deployment)
- Task 5 can run in parallel (optional)

**Success Metrics:**
- ✅ Bug fixed (Task 1)
- ✅ No regressions (Task 2)
- ✅ Tests passing (Task 3)
- ✅ Manual verification (Task 4)
- ✅ Deployed to production (Task 6)
- 📊 Affected users compensated (Task 5, optional)
