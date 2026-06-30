# Provider Gender Preference Implementation

## Overview
This feature allows customers to specify their preferred provider gender when making one-time on-demand bookings. When a preference is selected (Male or Female), only providers matching that gender will receive notifications for the booking.

## Changes Made

### 1. Frontend (React Native iOS App)

#### `apps/servease-ios/src/BookingDialog/BookingDialog.tsx`
- Added `genderPreference` state initialized to "No Preference"
- Created `renderGenderPreference()` function with UI for selecting Male/Female/No Preference
- Added gender preference selector **only for One-time bookings** (not Short-term or Monthly)
- Gender preference resets to "No Preference" when modal closes
- Passes selected preference in `onSave` callback

#### `apps/servease-ios/src/ServiceDialogs/ServiceBookingFlow.tsx`
- Updated booking payload to include `provider_gender_preference` field
- Sends the selected gender preference to backend during booking creation

#### `apps/servease-ios/src/services/bookingService.ts`
- BookingPayload interface supports the new `provider_gender_preference` field

### 2. Backend (Node.js/PostgreSQL)

#### Database Schema Changes

**Migration File:** `database/sql/106_provider_gender_preference.sql`
```sql
ALTER TABLE public.engagements
  ADD COLUMN provider_gender_preference VARCHAR(50) DEFAULT 'No Preference';
```

**To run the migration:**
```bash
npm run db:migrate
```

**Schema Update:** `services/payments/src/config/db/schema.sql`
- Added `provider_gender_preference` column to engagements table definition

#### API Changes

**File:** `services/payments/src/routes/v2/createEngagements.js`
- Extracts `provider_gender_preference` from request body
- Saves preference to engagements table during booking creation
- Default value: "No Preference"

#### Provider Notification Filtering

**File:** `services/payments/src/services/onDemandProviderBroadcast.js`

Modified three key functions:

1. **`fetchVacationPriorityOnDemandProviders()`**
   - Added `genderPreference` parameter
   - Filters vacation priority providers by gender when preference is specified
   - SQL adds `WHERE sp.gender = $genderPreference` clause

2. **`fetchBroadcastEligibleProviders()`**
   - Added `genderPreference` parameter
   - Filters general eligible providers by gender when preference is specified
   - SQL adds `WHERE sp.gender = $genderPreference` clause

3. **`broadcastOnDemandToProviders()`**
   - Extracts `provider_gender_preference` from engagement object
   - Passes gender preference to both fetch functions
   - Logs gender filtering results for monitoring

## How It Works

### Customer Flow
1. Customer opens One-time booking dialog
2. Selects date/time and service duration
3. (Optional) Selects provider gender preference: Male, Female, or No Preference
4. Confirms booking and proceeds to checkout
5. Backend creates engagement with gender preference stored

### Provider Notification Flow
1. After successful payment, backend triggers on-demand provider broadcast
2. System reads `provider_gender_preference` from engagement
3. If preference is "Male" or "Female":
   - SQL queries filter providers by matching gender
   - Only matching providers are included in notification list
4. If preference is "No Preference":
   - All eligible providers are notified (default behavior)
5. Providers receive notifications based on proximity and availability

## Database Structure

### Engagements Table
```sql
provider_gender_preference VARCHAR(50) DEFAULT 'No Preference'
```

Valid values:
- `'Male'` - Only male providers notified
- `'Female'` - Only female providers notified
- `'No Preference'` - All providers notified (default)

### ServiceProvider Table
Existing column used for filtering:
```sql
gender VARCHAR(255)
```

## Testing

### Test Cases
1. **No Preference** - All eligible providers should receive notifications
2. **Male Preference** - Only male providers within radius should be notified
3. **Female Preference** - Only female providers within radius should be notified
4. **Short-term/Monthly** - Gender preference UI should not appear
5. **Database** - Verify gender preference is saved correctly in engagements table

### Manual Testing Steps
1. Create a one-time booking with "Male" preference
2. Check logs for: `[Gender Filter] Engagement XXX: filtering for Male providers`
3. Verify only male providers receive notifications
4. Check `engagements` table to confirm `provider_gender_preference = 'Male'`

### SQL Verification Query
```sql
SELECT 
  e.engagement_id,
  e.provider_gender_preference,
  e.booking_type,
  e.service_type,
  e.created_at
FROM engagements e
WHERE e.provider_gender_preference != 'No Preference'
ORDER BY e.created_at DESC
LIMIT 10;
```

## Logging

Gender filtering is logged in the backend:
```javascript
console.log(`[Gender Filter] Engagement ${engagement.engagement_id}: filtering for ${genderPreference} providers. Found ${distances.length} eligible providers.`);
```

Monitor logs to verify:
- Gender preference is being read correctly
- Appropriate number of providers are being filtered
- Notifications are sent only to matching providers

## Performance Considerations

- Index created on `provider_gender_preference` for efficient filtering
- Index is partial (only non-'No Preference' values)
- SQL filtering happens at database level for optimal performance
- No additional API calls required for gender filtering

## Future Enhancements

Potential improvements:
1. Add gender preference to Short-term and Monthly bookings
2. Allow customers to save default gender preference in profile
3. Add analytics dashboard for gender preference usage
4. Support for non-binary/other gender options
5. Provider acceptance rate analytics by gender preference

## Rollback Plan

If issues arise, rollback steps:
1. Remove gender filtering from broadcast queries
2. Keep database column for historical data
3. Hide UI selector in frontend
4. Revert to notifying all eligible providers

## Notes

- Gender preference only applies to **one-time on-demand bookings**
- Short-term and Monthly bookings always assign a specific provider upfront
- Default "No Preference" maintains backward compatibility
- Existing bookings without preference are treated as "No Preference"
- Provider's gender field must be set for filtering to work correctly

## Support

For issues or questions:
- Check backend logs for `[Gender Filter]` entries
- Verify provider `gender` field is populated in database
- Confirm migration 106 was applied successfully
- Test with different gender preferences to isolate issues
