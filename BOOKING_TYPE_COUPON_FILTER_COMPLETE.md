# Booking Type Coupon Filtering - Implementation Complete

## Overview
Implemented booking_type-based coupon filtering so customers only see relevant coupons for their booking flow (MONTHLY/ONDEMAND/SHORTTERM). This solves the issue where the RONIT-TEST coupon (ONDEMAND MAID with 100% discount) wasn't showing in the iOS app's on-demand booking flow.

## Changes Made

### 1. Database Schema
**File**: `database/sql/115_add_booking_type_to_coupons.sql`
- Added `booking_type` column to `coupons` table
- Type: `VARCHAR(20)` with CHECK constraint
- Valid values: `'MONTHLY'`, `'ONDEMAND'`, `'SHORTTERM'`
- Nullable for backward compatibility (NULL = valid for all booking types)

```sql
ALTER TABLE coupons 
ADD COLUMN IF NOT EXISTS booking_type VARCHAR(20) 
CHECK (booking_type IN ('MONTHLY', 'ONDEMAND', 'SHORTTERM'));
```

**Status**: ✅ Pushed, awaiting GitHub Actions execution

### 2. Backend - Coupon Model
**File**: `services/coupons/src/models/coupon.model.js`
- Added `booking_type` field to Coupon model
- Type: `DataTypes.ENUM('MONTHLY', 'ONDEMAND', 'SHORTTERM')`
- Allows NULL

**Commit**: `a25aac9`

### 3. Backend - Coupon Service
**File**: `services/coupons/src/services/coupon.service.js`
- Added `matchesBookingType(requestedType, couponBookingType)` helper function
- Normalizes `ON_DEMAND` ↔ `ONDEMAND` for consistency
- Treats NULL booking_type as "valid everywhere"
- Updated `getCouponsForCustomer()` to filter by bookingType parameter

**Logic**:
```javascript
function matchesBookingType(requestedType, couponBookingType) {
  if (!couponBookingType) return true; // NULL = valid everywhere
  if (!requestedType) return true;     // No filter requested
  
  // Normalize variations
  const normalized = requestedType.replace('_', '').toUpperCase();
  const couponNormalized = couponBookingType.replace('_', '').toUpperCase();
  
  return normalized === couponNormalized;
}
```

**Commit**: `6aab5b5`

### 4. Backend - Coupon Controller
**File**: `services/coupons/src/controllers/coupon.controller.js`
- Updated `getCouponsForCustomer()` to accept `bookingType` query parameter
- Passes bookingType to service layer

**API Endpoint**:
```
GET /api/coupons/customer/:id?serviceType=MAID&bookingType=ONDEMAND
```

**Commit**: `6aab5b5`

### 5. iOS - Coupon Service
**File**: `apps/servease-ios/src/services/couponService.ts`
- Updated `fetchCustomerCoupons()` to accept `bookingType` option
- Passes bookingType as query parameter to backend API

```typescript
export async function fetchCustomerCoupons(
  customerId: number,
  serviceType: 'COOK' | 'MAID',
  options?: {
    userCity?: string;
    bookingType?: string; // ← NEW
  }
): Promise<CustomerCoupon[]>
```

**Commit**: `0fd84d8`

### 6. iOS - Service Booking Flow
**File**: `apps/servease-ios/src/ServiceDialogs/ServiceBookingFlow.tsx`
- Updated `loadAvailableCoupons()` to pass bookingType when fetching coupons
- Normalizes booking type: `SHORT_TERM` → `SHORTTERM`, `ON_DEMAND` → `ONDEMAND`

```typescript
const normalizedBookingType =
  cfg.bookingType === "SHORT_TERM" ? "SHORTTERM" :
  cfg.bookingType === "ON_DEMAND" ? "ONDEMAND" :
  cfg.bookingType;

return fetchCustomerCoupons(customerId, cfg.serviceType, {
  bookingType: normalizedBookingType,
});
```

**Commit**: `0fd84d8`

### 7. Admin UI Enhancements
**File**: `apps/servase-ui/src/components/Admin/Dashboard/Coupons.tsx`
- Added booking_type field to coupon creation/editing form
- Added booking_type column to AG Grid display
- All cellRenderers converted to React components (not HTML strings)
- Added search with 300ms debounce
- Added column visibility toggle with Select All/Deselect All
- Fixed API endpoints to match backend routes

**Commit**: `e0b4b65`

## Design Decisions

### When to Pass bookingType

**✅ Pass bookingType**:
- **ServiceBookingFlow** - Specific booking context (monthly/on-demand/short-term)
- User is in a specific booking flow, should only see coupons for that booking type

**❌ Don't Pass bookingType**:
- **CartDialog/CouponDialog** - General cart/checkout
- Cart may contain mixed items from different booking types
- Showing all eligible coupons is more appropriate

### Backend Filtering Logic
- If `coupon.booking_type` is NULL → coupon is valid for ALL booking types
- If `coupon.booking_type` is set → coupon only applies to that specific booking type
- Normalizes `ON_DEMAND` ↔ `ONDEMAND` for consistency between frontend and backend

## Git Commits

### Monorepo (main)
- `e0b4b65` - servase-ui: Admin coupon UI enhancements
- `a25aac9` - coupons: Add booking_type field to Coupon model
- `6aab5b5` - coupons: Add booking_type filtering support
- `bfa8704` - database: Add booking_type column migration
- `d1aa7ba` - chore: Update submodules (servase-ui, coupons, database)
- `424eeac` - chore: Update servease-ios submodule
- `b490a49` - chore: Update servease-ios submodule (booking_type filtering support)

### servease-ios (submodule)
- `0fd84d8` - feat(coupons): Add booking_type filtering support in iOS app

## Testing Instructions

### Prerequisites
1. Wait for GitHub Actions to run database migration (`115_add_booking_type_to_coupons.sql`)
2. Update RONIT-TEST coupon to set booking_type:
   ```sql
   UPDATE coupons SET booking_type='ONDEMAND' WHERE coupon_code='RONIT-TEST';
   ```

### Test Scenario 1: iOS On-Demand MAID Booking
1. Open servease-ios app
2. Navigate to MAID service
3. Select **On-Demand** booking type
4. Click "Apply Coupon" or view available coupons
5. **Expected**: RONIT-TEST coupon should appear in the list
6. Apply the coupon
7. **Expected**: 100% discount applied

### Test Scenario 2: iOS Monthly MAID Booking
1. Open servease-ios app
2. Navigate to MAID service
3. Select **Monthly** booking type
4. Click "Apply Coupon" or view available coupons
5. **Expected**: RONIT-TEST coupon should NOT appear (it's ONDEMAND only)

### Test Scenario 3: Admin UI
1. Open admin UI: https://coupons-426f.onrender.com/api/coupons/admin
2. Search for "RONIT-TEST"
3. **Expected**: booking_type column shows "ONDEMAND"
4. Edit the coupon
5. Change booking_type to "MONTHLY"
6. Save
7. **Expected**: Coupon now only applies to monthly bookings

### Test Scenario 4: Generic Cart (No Filtering)
1. Add items to cart (mixed types)
2. Open cart dialog
3. View available coupons
4. **Expected**: Shows all eligible coupons regardless of booking_type

## API Examples

### Fetch Coupons for On-Demand MAID Booking
```bash
curl -X GET 'https://coupons-426f.onrender.com/api/coupons/customer/123?serviceType=MAID&bookingType=ONDEMAND'
```

### Fetch Coupons for Monthly COOK Booking
```bash
curl -X GET 'https://coupons-426f.onrender.com/api/coupons/customer/123?serviceType=COOK&bookingType=MONTHLY'
```

### Fetch All Coupons (No bookingType filter)
```bash
curl -X GET 'https://coupons-426f.onrender.com/api/coupons/customer/123?serviceType=MAID'
```

## Remaining Tasks

1. ⏳ **Run Database Migration** (via GitHub Actions)
   - File: `database/sql/115_add_booking_type_to_coupons.sql`
   - Adds `booking_type` column to production database

2. ⏳ **Update RONIT-TEST Coupon**
   ```sql
   UPDATE coupons SET booking_type='ONDEMAND' WHERE coupon_code='RONIT-TEST';
   ```

3. ✅ **Backend Changes** - All pushed and deployed
4. ✅ **iOS Changes** - All pushed
5. ✅ **Admin UI Changes** - All pushed

## Files Changed

### Backend
- `services/coupons/src/models/coupon.model.js`
- `services/coupons/src/services/coupon.service.js`
- `services/coupons/src/controllers/coupon.controller.js`
- `database/sql/115_add_booking_type_to_coupons.sql`

### Frontend (iOS)
- `apps/servease-ios/src/services/couponService.ts`
- `apps/servease-ios/src/ServiceDialogs/ServiceBookingFlow.tsx`

### Admin UI
- `apps/servase-ui/src/components/Admin/Dashboard/Coupons.tsx`

## Known Issues / Notes

1. **Migration Timing**: Database migration must run before the feature works in production
2. **Backward Compatibility**: Existing coupons with NULL booking_type will continue to work for all booking types
3. **Case Sensitivity**: Backend normalizes `ON_DEMAND` and `ONDEMAND` to the same value
4. **Cart Behavior**: CartDialog intentionally does NOT filter by bookingType (shows all eligible coupons)

## Success Criteria

✅ Backend API accepts bookingType parameter
✅ Backend filters coupons by booking_type
✅ iOS app passes bookingType in specific booking flows
✅ Admin UI shows and allows editing booking_type
✅ Database migration created
✅ All changes pushed to GitHub

⏳ Database migration executed
⏳ RONIT-TEST coupon updated with booking_type='ONDEMAND'
⏳ End-to-end test: RONIT-TEST appears in iOS on-demand MAID booking

## Next Steps

1. Monitor GitHub Actions for migration execution
2. Manually update RONIT-TEST coupon in production database
3. Test end-to-end in iOS app (on-demand MAID booking should show RONIT-TEST)
4. Monitor coupon usage metrics
5. Consider adding booking_type filtering to web UI (servase-ui booking flows)
