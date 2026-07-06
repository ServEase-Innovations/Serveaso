# Wallet Refund Bug Fix - Modified Bookings

## Quick Summary

**Bug:** Users who modify a booking and then cancel it do not receive their wallet refund.

**Root Cause:** Cancellation endpoint fetches the latest payment (modification fee) instead of the original booking payment.

**Fix:** Change payment query to filter for `base_amount > 0` and order by `payment_id ASC`.

**Impact:** Critical - Financial loss for affected users.

---

## Files in This Spec

1. **bugfix.md** - Bug description, current vs expected behavior, reproduction steps
2. **design.md** - Technical analysis, root cause, solution design, edge cases
3. **tasks.md** - Implementation tasks, testing plan, deployment checklist

---

## Quick Start

### For Developers
1. Read `bugfix.md` to understand the issue
2. Review `design.md` for technical details
3. Follow `tasks.md` for implementation steps

### One-Line Fix
Change line 216-221 in `services/payments/src/routes/v2/engagementsV2.js`:

**From:**
```sql
WHERE engagement_id = $1 ORDER BY payment_id DESC LIMIT 1
```

**To:**
```sql
WHERE engagement_id = $1 AND COALESCE(base_amount, 0) > 0 ORDER BY payment_id ASC LIMIT 1
```

---

## Testing Checklist

- [ ] Task 1: Update cancellation query
- [ ] Task 2: Audit other endpoints
- [ ] Task 3: Add unit tests (5+ cases)
- [ ] Task 4: Manual integration testing
- [ ] Task 5: Database audit (optional)
- [ ] Task 6: Deploy to production

---

## Estimated Time

- **Critical Fix:** 30 minutes (Task 1)
- **Full Implementation:** 6-8 hours (all tasks)
- **Target Deployment:** 2 days from start

---

## Key Stakeholders

- **Engineering:** Payment service team
- **QA:** Testing team
- **Product:** User experience team
- **Support:** Customer support team
- **Finance:** Potential user compensation

---

## Success Metrics

- ✅ Modified bookings can be cancelled with refunds
- ✅ Wallet balances updated correctly
- ✅ Razorpay refunds initiated
- ✅ No regression in existing flows
- ✅ Support tickets about refunds decrease

---

## Related Documentation

- [Booking Modification Flow](../../../services/payments/src/services/scheduleModification.service.js)
- [Refund Service](../../../services/payments/src/services/bookingPaymentRefund.service.js)
- [Wallet Service](../../../services/payments/src/services/customerWallet.service.js)
- [Cancellation Policy](../../../services/payments/src/services/cancellationPolicy.js)
