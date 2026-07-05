# Actual End Time Fix ✅

**Date**: July 5, 2026  
**Issue**: Actual end time not showing in date-wise timeline for completed services  
**Status**: Fixed

---

## 🐛 Problem

When viewing completed services in the date-wise timeline, the UI showed:
- ✅ Start Time (scheduled)
- ✅ Started At (actual) with green checkmark
- ✅ End Time (scheduled)
- ❌ **Ended At (actual) - MISSING**

**Example**:
```
Jul 4  Sat  [✓ Completed]

Start Time
06:00

End Time
08:00

Started At
22:54 ✓

[Ended At was missing here!]
```

---

## 🔍 Root Cause

When a service is completed via the `/service-days/:id/complete` endpoint, the backend was updating:
- ✅ `status` = 'COMPLETED'
- ✅ `completed_at` = NOW()
- ✅ `otp_verified` = true
- ❌ **`actual_end_epoch` - NOT SET**

**Code Location**: `services/payments/src/routes/engagementService.js` (line ~351)

**Old Code**:
```javascript
UPDATE service_days
SET status = 'COMPLETED',
    completed_at = NOW(),
    otp_verified = true
WHERE service_day_id = $1
```

**Issue**: The `actual_end_epoch` column was never populated, so the frontend had no data to display for "Ended At".

---

## ✅ Solution

Updated the service completion query to capture the actual end time:

**New Code**:
```javascript
UPDATE service_days
SET status = 'COMPLETED',
    completed_at = NOW(),
    otp_verified = true,
    actual_end_epoch = EXTRACT(EPOCH FROM NOW())::BIGINT  -- ✅ NEW
WHERE service_day_id = $1
```

**What This Does**:
- Captures the exact Unix timestamp (epoch) when the service is completed
- Stores it in the `actual_end_epoch` column in the `service_days` table
- Frontend can then display this as "Ended At: HH:mm ✓"

---

## 🔄 Data Flow (After Fix)

### When Service Provider Completes Service:

```
1. Provider clicks "Complete Service"
   ↓
2. Customer enters OTP
   ↓
3. POST /api/engagement-service/service-days/:id/complete
   ↓
4. Backend validates OTP
   ↓
5. Backend updates service_days:
   - status = 'COMPLETED'
   - completed_at = NOW()
   - actual_end_epoch = CURRENT_TIMESTAMP  ✅ NEW
   ↓
6. Frontend refreshes engagement details
   ↓
7. DateWiseTimeline fetches service days
   ↓
8. UI displays "Ended At: 00:54 ✓" (actual time with checkmark)
```

---

## 📊 Before vs After

### Before Fix:
```
Jul 4  Sat  [✓ Completed]
┌─────────────────────────────────┐
│ Start Time        End Time       │
│ 06:00            08:00          │
│                                 │
│ Started At                      │
│ 22:54 ✓                        │
└─────────────────────────────────┘
```

### After Fix:
```
Jul 4  Sat  [✓ Completed]
┌─────────────────────────────────┐
│ Start Time        End Time       │
│ 06:00            08:00          │
│                                 │
│ Started At        Ended At      │
│ 22:54 ✓          00:54 ✓       │
└─────────────────────────────────┘
```

---

## 🧪 Testing

### Test Case 1: Complete a New Service

**Steps**:
1. Start a service (sets `actual_start_epoch`)
2. Complete the service (now sets `actual_end_epoch`)
3. Refresh booking details
4. Open date-wise timeline

**Expected Result**:
- ✅ "Started At" shows actual start time with ✓
- ✅ "Ended At" shows actual end time with ✓
- ✅ Both times are highlighted in green/blue
- ✅ Service duration can be calculated from actual times

### Test Case 2: View Existing Completed Services

**For Old Services** (completed before this fix):
- ✅ "Started At" shows (if captured)
- ⚠️ "Ended At" will NOT show (data doesn't exist)
- ℹ️ This is expected - old data wasn't captured

**For New Services** (completed after this fix):
- ✅ "Started At" shows
- ✅ "Ended At" shows
- ✅ Complete timeline data available

---

## 🗄️ Database Impact

### Column Used:
- **Table**: `service_days`
- **Column**: `actual_end_epoch` (BIGINT)
- **Migration**: Already exists from migration `107_engagement_timeline_recalculation.sql`

### No Migration Needed:
The column already existed from the initial timeline recalculation feature. We just weren't populating it on service completion!

### Backfill Old Data (Optional):

If you want to add approximate end times to old completed services:

```sql
-- Backfill old completed services with estimated end times
-- Uses completed_at timestamp as the end time
UPDATE service_days
SET actual_end_epoch = EXTRACT(EPOCH FROM completed_at)::BIGINT
WHERE status = 'COMPLETED'
  AND completed_at IS NOT NULL
  AND actual_end_epoch IS NULL;

-- Verify
SELECT 
  service_day_id,
  service_date,
  status,
  to_timestamp(actual_start_epoch) AT TIME ZONE 'Asia/Kolkata' as started_at,
  to_timestamp(actual_end_epoch) AT TIME ZONE 'Asia/Kolkata' as ended_at
FROM service_days
WHERE status = 'COMPLETED'
  AND actual_end_epoch IS NOT NULL
LIMIT 10;
```

---

## 📝 Related Files

### Backend:
- `services/payments/src/routes/engagementService.js` (line ~351-360)
  - Updated: Service completion query to set `actual_end_epoch`

### Frontend (No Changes Needed):
- `apps/servase-ui/src/components/Common/BookingTimeline/DateWiseTimeline.tsx`
  - Already checks for `serviceDay.actual.end_time`
  - Already displays "Ended At" when data is available
  - Already shows checkmark for actual times

### Database:
- Table: `service_days`
- Column: `actual_end_epoch` (already exists)

---

## ✅ Summary

**What Was Wrong**: `actual_end_epoch` was never set when completing services

**What We Fixed**: Added `actual_end_epoch = EXTRACT(EPOCH FROM NOW())::BIGINT` to completion query

**Impact**: 
- New completed services now show actual end time
- Old services won't have this data (can backfill if needed)
- No breaking changes
- No frontend changes required

**Status**: ✅ **FIXED - Ready for Testing**

