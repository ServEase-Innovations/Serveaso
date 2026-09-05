# Monthly & Short Term Booking API Call Fix

## Issue
When users selected **Monthly** or **Short term** booking options, then picked a date/time and clicked **Confirm**, no API call was being made to create the engagement. The code was:
- ✅ Saving booking details to Redux
- ✅ Navigating to details page
- ❌ **Never calling the backend API** to create the engagement

## Root Cause
In both `ServicesDialog.tsx` and `Header.tsx`, the `handleBookingSave` function had conditional logic:
- **Date bookings**: Opens service dialog → triggers `BookingService.bookAndPay()` API call
- **Monthly/Short term bookings**: Just navigates to DETAILS page → **NO API call**

```typescript
// BEFORE (broken)
if (selectedRadioButtonValue === "Date") {
  setOpenServiceDialog(true);  // Opens service dialog that makes API call
} else {
  sendDataToParent(DETAILS);   // Just navigates - NO API CALL
}
```

## Solution
Changed the flow to **always open the service dialog** for all booking types (Date, Monthly, Short term). The service dialog contains the `ServiceBookingFlow` component which:
1. Calls `BookingService.bookAndPay()` to create the engagement
2. Handles payment via Razorpay
3. Shows success confirmation
4. Navigates appropriately after successful booking

```typescript
// AFTER (fixed)
// Open service-specific dialog for ALL booking types (Date, Monthly, Short term)
// This ensures the API call (createEngagement/bookAndPay) is made for all booking types
setOpenServiceDialog(true);
```

## Files Changed
1. **`apps/servase-ui/src/components/ServicesDialog/ServicesDialog.tsx`**
   - Line ~200: Fixed `handleBookingSave` to always open service dialog
   
2. **`apps/servase-ui/src/components/Header/Header.tsx`**
   - Line ~892: Fixed `handleBookingSave` to always open service dialog

## How It Works Now

### Booking Flow (All Types)
1. User clicks service (Cook/Maid/Nanny)
2. Booking dialog opens
3. User selects booking type: **Date** / **Monthly** / **Short term**
4. User picks date/time and clicks **Confirm**
5. Booking details saved to Redux
6. **Service dialog opens** (MaidServiceDialog/CookServicesDialog/NannyServicesDialog)
7. Inside service dialog, `ServiceBookingFlow` component:
   - Shows pricing breakdown
   - Allows task/responsibility selection
   - Validates address
   - Calls **`BookingService.bookAndPay(payload)`** API
   - Opens Razorpay payment
   - Verifies payment
   - Shows success confirmation
8. User redirected to bookings page

## Testing
To test the fix:
1. Start dev server: `cd apps/servase-ui && npm start`
2. Go to home page
3. Click "Select Booking Option"
4. Choose **Monthly** booking type
5. Select a start date and time
6. Click **Confirm**
7. **Expected**: Service dialog opens showing pricing and tasks
8. Complete the booking flow
9. **Expected**: API calls to `/api/v2/createEngagements` should be visible in Network tab

## API Endpoints Used
- `POST /api/v2/createEngagements` - Creates the engagement
- `POST /api/v2/createEngagements/verify` - Verifies Razorpay payment

## Impact
- ✅ Monthly bookings now properly create engagements via API
- ✅ Short term bookings now properly create engagements via API  
- ✅ Payment flow works for all booking types
- ✅ Consistent user experience across all booking types
- ✅ Backend receives booking data correctly

## Related Components
- `ServiceBookingFlow.tsx` - Handles the actual API call and payment
- `BookingService.ts` - Contains `bookAndPay()` and `createEngagement()` methods
- `MaidServiceDialog.tsx` / `CookServicesDialog.tsx` / `NannyServicesDialog.tsx` - Wrap ServiceBookingFlow

## Notes
- This fix ensures feature parity across all booking types
- The service dialog already had the correct implementation - we just weren't opening it for Monthly/Short term bookings
- No changes needed to backend APIs
- No database migrations required
