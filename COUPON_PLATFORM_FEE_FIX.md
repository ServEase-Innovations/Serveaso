# Coupon Platform Fee Fix - 100% Discount Now Works Correctly

## Issue
When applying a 100% discount coupon (like RONIT-TEST), the iOS app was showing ₹187 payable instead of ₹0.

## Root Cause
Platform fees (6%) and GST (18% on fees) were being calculated **AFTER** the coupon discount, resulting in:
- Original price: ₹175
- Apply 100% discount: ₹0
- **Then add platform fees**: ₹10.50 + ₹1.89 = ₹12.39
- Total shown: ₹187.39 ❌

This meant 100% discount coupons could never result in truly free bookings.

## Solution
Changed the calculation order to include platform fees **BEFORE** applying coupon discounts:

### New Flow:
1. Service price: ₹175
2. **Add platform fee (6%)**: ₹10.50
3. **Add GST (18% on fee)**: ₹1.89
4. **Subtotal before coupon**: ₹187.39
5. **Apply 100% discount coupon**: -₹187.39
6. **Final total**: ₹0 ✅

## Changes Made

### 1. Backend - Quote Engine (`services/payments`)
**File**: `services/payments/src/services/pricing/quoteEngine.js`

Added platform fees and GST calculation BEFORE coupon validation:

```javascript
// Calculate platform fees BEFORE applying coupon
const PLATFORM_FEE_RATE = 0.06;
const GST_ON_PLATFORM_FEE_RATE = 0.18;

const serviceSubtotal = total;
const platformFee = Math.round(serviceSubtotal * PLATFORM_FEE_RATE * 100) / 100;
const gst = Math.round(platformFee * GST_ON_PLATFORM_FEE_RATE * 100) / 100;

// Add as line items
lineItems.push({
  description: `Platform fee (6%)`,
  amount: platformFee,
});
lineItems.push({
  description: `GST (18% on platform fee)`,
  amount: gst,
});

// Total INCLUDING fees (before coupon)
total = serviceSubtotal + platformFee + gst;

// NOW apply coupon to the full total
if (couponCode) {
  const couponResult = await validateCouponForQuote({
    couponCode,
    orderValue: total,  // ← Apply to total including fees
    ...
  });
  total = Math.max(0, total - couponResult.discount_amount);
}
```

**Benefits**:
- Coupons now discount the total including all fees
- 100% discount coupons result in ₹0 total
- Platform fees are visible in the quote breakdown
- Consistent behavior across all discount percentages

### 2. iOS App (`apps/servease-ios`)
**File**: `apps/servease-ios/src/ServiceDialogs/ServiceBookingFlow.tsx`

Removed duplicate platform fee calculation:

**Before**:
```typescript
const paymentTotals = useMemo(
  () => computePaymentTotals(serviceTotal),  // ← Was adding fees again!
  [serviceTotal]
);
const payableTotal = paymentTotals.total_amount;

const displayBreakdown = useMemo(
  () => appendPaymentFeeRows(quotePreview.breakdown, serviceTotal),  // ← Duplicate fees!
  [quotePreview.breakdown, serviceTotal]
);
```

**After**:
```typescript
// Quote already includes platform fees, use it directly
const payableTotal = serviceTotal;

// Quote breakdown already includes fees
const displayBreakdown = quotePreview.breakdown;
```

## Testing

### Test Case 1: 100% Discount Coupon
**Setup**:
- Service: On-Demand MAID
- Original price: ₹175
- Coupon: RONIT-TEST (100% discount)

**Expected Breakdown**:
```
Service charge:     ₹175.00
Platform fee (6%):  ₹10.50
GST (18% on fee):   ₹1.89
─────────────────────────────
Subtotal:           ₹187.39
Coupon RONIT-TEST: -₹187.39
─────────────────────────────
Total:              ₹0.00 ✅
```

### Test Case 2: 50% Discount Coupon
**Setup**:
- Service: On-Demand MAID
- Original price: ₹175
- Coupon: HALF-OFF (50% discount)

**Expected Breakdown**:
```
Service charge:     ₹175.00
Platform fee (6%):  ₹10.50
GST (18% on fee):   ₹1.89
─────────────────────────────
Subtotal:           ₹187.39
Coupon HALF-OFF:    -₹93.70
─────────────────────────────
Total:              ₹93.69 ✅
```

### Test Case 3: Minimum Final Amount
**Setup**:
- Service: On-Demand MAID
- Original price: ₹175
- Coupon: MAID1-ONDEMAND (₹99,999 discount, minimum_final_amount: ₹1)

**Expected Breakdown**:
```
Service charge:     ₹175.00
Platform fee (6%):  ₹10.50
GST (18% on fee):   ₹1.89
─────────────────────────────
Subtotal:           ₹187.39
Coupon discount:   -₹186.39
─────────────────────────────
Total:              ₹1.00 ✅
```

## Commits

### Backend (payments service)
- `c2d2e2d` - fix(pricing): Include platform fees in quote before applying coupons

### Frontend (servease-ios)
- `1ce9132` - fix(pricing): Remove duplicate platform fee calculation

### Monorepo
- `aafe305` - fix: Platform fees now included in quote before coupon discount
- `edd0ecf` - chore: Update servease-ios submodule (platform fee fix)

## Migration Notes

### Breaking Change
This changes the quote API response structure. The `total` field now includes platform fees and GST.

**Before**:
```json
{
  "total": 175,
  "line_items": [
    { "description": "Service", "amount": 175 }
  ]
}
```

**After**:
```json
{
  "total": 187.39,
  "line_items": [
    { "description": "Service", "amount": 175 },
    { "description": "Platform fee (6%)", "amount": 10.50 },
    { "description": "GST (18% on platform fee)", "amount": 1.89 }
  ]
}
```

### Compatibility
- ✅ **iOS app**: Updated to use quote total directly (no duplicate fees)
- ⚠️ **Web UI**: May need similar update if it also adds platform fees client-side
- ✅ **Backend booking creation**: Uses quote total directly, no changes needed

## Next Steps

1. ✅ Deploy payments service (Render auto-deploys from git push)
2. ✅ Rebuild iOS app
3. ⚠️ **Check web UI** (`servase-ui`) - May need similar fix if it adds platform fees
4. ✅ Test 100% discount coupons in production
5. ✅ Update RONIT-TEST coupon: `booking_type = 'ONDEMAND'`

## Related Issues Fixed

- ✅ 100% discount coupons now work correctly (show ₹0)
- ✅ Platform fees are visible in the breakdown
- ✅ Consistent calculation across all discount types
- ✅ No more duplicate fee calculation
- ✅ Coupon discounts now apply to the full booking cost (service + fees)

## Summary

The fix ensures that coupons discount the **total booking cost** (service + platform fees + GST), not just the service amount. This is the correct and expected behavior for promotional codes - a 100% discount should result in completely free service, including waiving all fees.
