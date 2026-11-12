# Coupon Debugging Guide - RONIT-TEST Not Showing in iOS

## Issue
The RONIT-TEST coupon (100% discount for ONDEMAND MAID) is not appearing in the iOS app when booking on-demand MAID service.

## Logging Added
Comprehensive logging has been added at every step of the coupon filtering process to help debug why the coupon isn't showing up.

## How to Check the Logs

### 1. Backend Logs (Coupons Service)

Check the coupons service logs when the iOS app makes the API request:

```bash
# If running locally
cd services/coupons
npm start

# Watch for logs like:
# [Controller.getCouponsForCustomer] Request: { customer_id: '123', serviceType: 'MAID', bookingType: 'ONDEMAND' }
# [getCouponsForCustomer] Found active coupons: 5
# [getCouponsForCustomer] Coupon data: { code: 'RONIT-TEST', service_type: 'MAID', booking_type: 'ONDEMAND' }
# [matchesBookingType] Input: { requestedType: 'ONDEMAND', couponBookingType: 'ONDEMAND' }
# [matchesBookingType] Result: { match: true }
```

**If running on Render.com**, check the logs at:
https://dashboard.render.com/web/srv-XXXXX (your coupons service ID)

### 2. iOS App Logs

Run the iOS app in debug mode and watch the console:

```bash
cd apps/servease-ios
npx react-native run-ios
# Or use Xcode to run and view Console output
```

Look for logs like:
```
[ServiceBookingFlow.loadAvailableCoupons] Calling fetchCustomerCoupons with: { customerId: 123, serviceType: 'MAID', bookingTypeCode: 'ON_DEMAND', normalizedBookingType: 'ONDEMAND' }
[fetchCustomerCoupons] Request params: { customerId: 123, serviceType: 'MAID', bookingType: 'ONDEMAND' }
[fetchCustomerCoupons] Final API params: { serviceType: 'MAID', bookingType: 'ONDEMAND' }
[fetchCustomerCoupons] Raw API response: { ... }
[fetchCustomerCoupons] Mapped coupons: 5 [...]
[fetchCustomerCoupons] Service type filter: { code: 'RONIT-TEST', requestedServiceType: 'MAID', couponServiceType: 'MAID', match: true }
[fetchCustomerCoupons] City filter: { code: 'RONIT-TEST', couponCity: null, userCity: 'Bangalore', match: true }
[fetchCustomerCoupons] Final filtered coupons: 2 [...]
```

## What to Look For

### Step 1: Check if Database Migration Ran
```sql
-- Connect to production database
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'coupons' AND column_name = 'booking_type';
```

**Expected**: Should return one row showing the `booking_type` column exists.
**If empty**: Database migration hasn't run yet. Wait for GitHub Actions to execute it.

### Step 2: Check RONIT-TEST Coupon Data
```sql
SELECT coupon_code, service_type, booking_type, isActive, start_date, end_date, booking_condition
FROM coupons 
WHERE coupon_code = 'RONIT-TEST';
```

**Expected**:
- `coupon_code`: RONIT-TEST
- `service_type`: MAID
- `booking_type`: ONDEMAND (or NULL if not yet updated)
- `isActive`: true
- `start_date`: in the past
- `end_date`: in the future
- `booking_condition`: ANY (or appropriate value)

**If booking_type is NULL**: Run this update:
```sql
UPDATE coupons SET booking_type='ONDEMAND' WHERE coupon_code='RONIT-TEST';
```

### Step 3: Analyze Backend Logs

Look for the request when iOS app loads coupons:

```
[Controller.getCouponsForCustomer] Request: { 
  customer_id: '123', 
  serviceType: 'MAID', 
  bookingType: 'ONDEMAND' 
}
```

Then follow the filtering steps:

1. **Found active coupons**: How many coupons are active and within date range?
2. **Booking condition filter**: Does RONIT-TEST pass? Check prior_booking_count.
3. **Service type filter**: Should match MAID.
4. **Booking type filter**: Should match ONDEMAND.

### Step 4: Common Issues

#### Issue: `bookingType` not in API request
**Symptoms**: Backend logs show `bookingType: null` or undefined
**Cause**: iOS app not passing bookingType parameter
**Check**: ServiceBookingFlow should log `normalizedBookingType: 'ONDEMAND'`

#### Issue: booking_type column doesn't exist
**Symptoms**: Backend error: `column "booking_type" does not exist`
**Cause**: Database migration not yet run
**Fix**: Wait for GitHub Actions or manually run migration

#### Issue: RONIT-TEST has `booking_type = NULL`
**Symptoms**: Coupon appears in all booking flows (or none if backend filters NULL differently)
**Cause**: Migration ran but coupon not updated
**Fix**: 
```sql
UPDATE coupons SET booking_type='ONDEMAND' WHERE coupon_code='RONIT-TEST';
```

#### Issue: Booking condition mismatch
**Symptoms**: Backend logs show "Booking condition filter: match: false"
**Cause**: Coupon has `booking_condition='FIRST_BOOKING'` but customer has prior bookings
**Check**: 
```sql
SELECT prior_booking_count FROM (backend response)
SELECT booking_condition FROM coupons WHERE coupon_code='RONIT-TEST'
```
**Fix**: If testing, either:
- Create a new test customer with 0 bookings
- OR change coupon: `UPDATE coupons SET booking_condition='ANY' WHERE coupon_code='RONIT-TEST'`

#### Issue: Service type mismatch
**Symptoms**: Backend logs show "Service type filter: match: false"
**Cause**: Coupon `service_type` doesn't match requested type
**Check**: Ensure `service_type='MAID'` not 'COOK'

#### Issue: Date range invalid
**Symptoms**: Coupon not in "Found active coupons" list
**Cause**: `start_date` is in the future or `end_date` is in the past
**Fix**: 
```sql
UPDATE coupons 
SET start_date = NOW() - INTERVAL '1 day',
    end_date = NOW() + INTERVAL '30 days'
WHERE coupon_code='RONIT-TEST';
```

## Log Output Examples

### Successful Case (Coupon Appears)
```
[Backend]
[Controller.getCouponsForCustomer] Request: { customer_id: '123', serviceType: 'MAID', bookingType: 'ONDEMAND' }
[getCouponsForCustomer] Found active coupons: 5
[getCouponsForCustomer] Coupon data: { code: 'RONIT-TEST', service_type: 'MAID', booking_type: 'ONDEMAND', booking_condition: 'ANY' }
[getCouponsForCustomer] Booking condition filter: { code: 'RONIT-TEST', booking_condition: 'ANY', priorBookingCount: 2, match: true }
[getCouponsForCustomer] Service type filter: { code: 'RONIT-TEST', requestedServiceType: 'MAID', couponServiceType: 'MAID', match: true }
[matchesBookingType] Input: { requestedType: 'ONDEMAND', couponBookingType: 'ONDEMAND' }
[matchesBookingType] Coupon booking_type matches requested type → true
[getCouponsForCustomer] Booking type filter: { code: 'RONIT-TEST', requestedBookingType: 'ONDEMAND', couponBookingType: 'ONDEMAND', match: true }
[getCouponsForCustomer] Final filtered coupons: 1
[Controller.getCouponsForCustomer] Service returned: { couponCount: 1, coupons: [{ code: 'RONIT-TEST', service_type: 'MAID', booking_type: 'ONDEMAND' }] }

[iOS]
[ServiceBookingFlow.loadAvailableCoupons] Calling fetchCustomerCoupons with: { customerId: 123, serviceType: 'MAID', bookingTypeCode: 'ON_DEMAND', normalizedBookingType: 'ONDEMAND', userCity: 'Bangalore' }
[fetchCustomerCoupons] Request params: { customerId: 123, serviceType: 'MAID', bookingType: 'ONDEMAND' }
[fetchCustomerCoupons] Normalized bookingType: ONDEMAND
[fetchCustomerCoupons] Final API params: { serviceType: 'MAID', bookingType: 'ONDEMAND' }
[fetchCustomerCoupons] Mapped coupons: 1 [{ code: 'RONIT-TEST', ... }]
[fetchCustomerCoupons] Service type filter: { code: 'RONIT-TEST', requestedServiceType: 'MAID', couponServiceType: 'MAID', match: true }
[fetchCustomerCoupons] City filter: { code: 'RONIT-TEST', couponCity: null, userCity: 'Bangalore', match: true }
[fetchCustomerCoupons] Final filtered coupons: 1 [{ code: 'RONIT-TEST', ... }]
[ServiceBookingFlow.loadAvailableCoupons] Received coupons: 1 [{ code: 'RONIT-TEST', ... }]
```

### Failed Case (Coupon Filtered Out by booking_type)
```
[Backend]
[matchesBookingType] Input: { requestedType: 'ONDEMAND', couponBookingType: 'MONTHLY' }
[matchesBookingType] Result: { normalizedRequested: 'ONDEMAND', normalizedCoupon: 'MONTHLY', match: false }
[getCouponsForCustomer] Booking type filter: { code: 'RONIT-TEST', requestedBookingType: 'ONDEMAND', couponBookingType: 'MONTHLY', match: false }
[getCouponsForCustomer] Final filtered coupons: 0
```

### Failed Case (booking_type is NULL - should match all)
```
[Backend]
[matchesBookingType] Input: { requestedType: 'ONDEMAND', couponBookingType: '' }
[matchesBookingType] Coupon booking_type is NULL/empty, matches all → true
[getCouponsForCustomer] Booking type filter: { code: 'RONIT-TEST', requestedBookingType: 'ONDEMAND', couponBookingType: null, match: true }
```

## Testing Checklist

Before reporting that the issue persists, verify:

- [ ] Database migration has run (`booking_type` column exists)
- [ ] RONIT-TEST coupon exists and is active
- [ ] RONIT-TEST has `booking_type='ONDEMAND'` (not NULL, not MONTHLY)
- [ ] RONIT-TEST has valid date range (start < now < end)
- [ ] RONIT-TEST has `service_type='MAID'`
- [ ] RONIT-TEST has `booking_condition='ANY'` OR customer has 0 prior bookings
- [ ] iOS app is passing `bookingType` parameter (check iOS logs)
- [ ] Backend receives `bookingType='ONDEMAND'` (check backend logs)
- [ ] Backend logs show RONIT-TEST passing all filters
- [ ] iOS logs show coupon in final filtered list

## Quick Test API Call

Test the API directly with curl:

```bash
# Replace {customer_id} with actual customer ID
curl -X GET 'https://coupons-426f.onrender.com/api/coupons/customer/{customer_id}?serviceType=MAID&bookingType=ONDEMAND' \
  -H 'Content-Type: application/json'
```

Expected response should include RONIT-TEST in the coupons array.

## Commits with Logging

- **iOS**: `3391b36` - feat(coupons): Add comprehensive logging for coupon fetching
- **Backend**: `7e22790` - feat(coupons): Add comprehensive logging for booking_type filtering
- **Monorepo**: `6cab4b2` - chore: Update submodules with coupon filtering logs

## Next Steps

1. Deploy/rebuild the backend coupons service to include logging
2. Rebuild the iOS app to include logging
3. Reproduce the issue (navigate to on-demand MAID booking, try to apply coupon)
4. Collect logs from both backend and iOS
5. Share the logs to identify where the filtering is failing

The logs will show exactly at which step the RONIT-TEST coupon is being filtered out, making it easy to identify and fix the issue.
