# Testing Guide: Dynamic Booking Timeline Recalculation

## Why You're Not Seeing Actual Start Time

**The timeline fields only appear AFTER the service provider starts the service.**

Currently showing:
```
Service Timeline
Start Time: 12:00 PM
End Time: 1:00 PM
```

This is **correct behavior** because:
1. The booking hasn't been started yet (status is NOT_STARTED or SCHEDULED)
2. `actual_start_epoch` is NULL in database (service hasn't begun)
3. Timeline component correctly falls back to scheduled times

---

## How to Test Timeline Recalculation

### Option 1: Using Postman/cURL (Recommended)

**Step 1: Create a Test Booking**
- Book a service for future time (e.g., 2:00 PM - 3:00 PM)
- Note down the `engagement_id` and `service_day_id`

**Step 2: Start the Service Early**
```bash
# Replace with your actual IDs
curl -X POST http://localhost:3000/api/v2/engagements/{engagement_id}/start \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "service_day_id": YOUR_SERVICE_DAY_ID
  }'
```

**Step 3: Check the Response**
You should see:
```json
{
  "success": true,
  "engagement_id": 12345,
  "timeline": {
    "scheduled_start_epoch": 1720101600,  // 2:00 PM
    "actual_start_epoch": 1720099800,     // Current time (e.g., 1:30 PM)
    "scheduled_end_epoch": 1720105200,    // 3:00 PM
    "actual_end_epoch": 1720103400,       // 2:30 PM (recalculated!)
    "duration_minutes": 60,
    "early_start_minutes": 30
  }
}
```

**Step 4: Refresh the Web UI**
- Go to My Bookings
- Click on the booking
- **You should now see**:

```
┌─────────────────────────────────────────────────┐
│ ⚠️ Service Started Early                        │
│ Service provider arrived 30 minutes before      │
│ scheduled time. Service duration (60 min)       │
│ has been preserved.                             │
├─────────────────────────────────────────────────┤
│ 🕐 Service Timeline                             │
│                                                 │
│ ● Start Time          1:30 PM                   │
│                       Scheduled: 2:00 PM        │
│                                                 │
│   Duration            60 minutes                │
│                                                 │
│ ○ End Time            2:30 PM                   │
│                       Originally: 3:00 PM       │
│                                                 │
│ ✓ Started 30 min early                          │
└─────────────────────────────────────────────────┘
```

---

### Option 2: Using Database Directly

**Step 1: Find a Test Booking**
```sql
SELECT engagement_id, service_type, start_epoch, end_epoch, task_status
FROM engagements
WHERE task_status = 'NOT_STARTED'
LIMIT 1;
```

**Step 2: Manually Simulate Service Start**
```sql
-- Let's say engagement_id = 12345
-- And start_epoch = 1720101600 (2:00 PM)

-- Calculate early start (30 minutes before = 1800 seconds)
-- actual_start = 1720101600 - 1800 = 1720099800 (1:30 PM)

-- Update engagement with timeline recalculation
UPDATE engagements
SET 
  actual_start_epoch = 1720099800,           -- 1:30 PM
  actual_end_epoch = 1720103400,             -- 2:30 PM (1:30 + 60 min)
  duration_minutes = 60,
  is_timeline_recalculated = true,
  early_start_minutes = 30,
  task_status = 'IN_PROGRESS',
  engagement_status = 'IN_PROGRESS'
WHERE engagement_id = 12345;
```

**Step 3: Refresh Web UI**
- The timeline should now show actual times

---

### Option 3: Using Feature Flag to Test with Current Time

**Enable Timeline Recalculation**
```bash
# Set environment variable
export FEATURE_FLAG_ENABLE_TIMELINE_RECALCULATION=true

# Or use Admin API
curl -X POST http://localhost:3000/api/admin/feature-flags/ENABLE_TIMELINE_RECALCULATION/enable \
  -H "Content-Type: application/json" \
  -d '{"percentage": 100}'
```

**Create Booking for NOW**
- Book a service that starts in the next 5 minutes
- Wait for time to pass
- Start the service via provider app or API

---

## Checking if Timeline Fields Exist in API Response

**Test the API Response**:
```bash
# Replace with your customer_id
curl http://localhost:3000/api/customers/YOUR_CUSTOMER_ID/engagements \
  -H "Authorization: Bearer YOUR_TOKEN" | jq '.ongoing[0]'
```

**What to Look For**:
```json
{
  "engagement_id": 12345,
  "start_epoch": 1720101600,
  "end_epoch": 1720105200,
  // These fields should exist (may be null if not started):
  "actual_start_epoch": 1720099800,        // ✓ This is what you need
  "actual_end_epoch": 1720103400,          // ✓ Recalculated end time
  "duration_minutes": 60,                  // ✓ Preserved duration
  "is_timeline_recalculated": true,        // ✓ Timeline was recalculated
  "early_start_minutes": 30                // ✓ How early it started
}
```

**If These Fields Are Missing**:
1. Check database migration ran: `SELECT actual_start_epoch FROM engagements LIMIT 1;`
2. Check backend is running latest code: `git log -1 --oneline`
3. Check feature flag is enabled (dev environment should be auto-enabled)

---

## Expected Behavior by Booking Status

### Status: NOT_STARTED / SCHEDULED
**Database**:
- `actual_start_epoch` = NULL
- `is_timeline_recalculated` = false

**Web UI Should Show**:
```
Service Timeline
● Start Time    12:00 PM
  Duration      60 minutes
○ End Time      1:00 PM
```
✅ **Correct** - No early start banner, uses scheduled times

---

### Status: IN_PROGRESS (Started Early)
**Database**:
- `actual_start_epoch` = 1720099800 (1:30 PM)
- `actual_end_epoch` = 1720103400 (2:30 PM)
- `is_timeline_recalculated` = true
- `early_start_minutes` = 30

**Web UI Should Show**:
```
⚠️ Service Started Early
Service provider arrived 30 minutes before scheduled time.
Service duration (60 min) has been preserved.

Service Timeline
● Start Time          1:30 PM
                      Scheduled: 2:00 PM
  Duration            60 minutes
○ End Time            2:30 PM
                      Originally: 3:00 PM
✓ Started 30 min early
```
✅ **Expected** - Green alert, actual times displayed

---

### Status: IN_PROGRESS (Started On Time)
**Database**:
- `actual_start_epoch` = 1720101600 (2:00 PM - same as scheduled)
- `actual_end_epoch` = 1720105200 (3:00 PM - same as scheduled)
- `is_timeline_recalculated` = true
- `early_start_minutes` = 0

**Web UI Should Show**:
```
Service Timeline
● Start Time    2:00 PM
  Duration      60 minutes
○ End Time      3:00 PM
```
✅ **Expected** - No early start banner (early_start_minutes = 0)

---

## Common Issues & Solutions

### Issue 1: "Start Time: 12:00 PM" (no actual time showing)
**Cause**: Service hasn't been started yet, `actual_start_epoch` is NULL
**Solution**: Start the service via API or provider app

### Issue 2: Timeline fields return NULL even after starting service
**Cause**: Feature flag disabled or backend not running latest code
**Solution**:
```bash
# Check feature flag
curl http://localhost:3000/api/admin/feature-flags | jq '.flags[] | select(.id=="ENABLE_TIMELINE_RECALCULATION")'

# Enable if disabled
curl -X POST http://localhost:3000/api/admin/feature-flags/ENABLE_TIMELINE_RECALCULATION/enable
```

### Issue 3: Database columns don't exist
**Cause**: Migration not run
**Solution**:
```bash
cd services/payments
psql -d your_database -f ../../database/sql/107_engagement_timeline_recalculation.sql
```

### Issue 4: "Module not found" errors in backend
**Cause**: ES6 module conversion not complete or dependencies not installed
**Solution**:
```bash
cd services/payments
npm install
pm2 restart payments
```

---

## Manual End-to-End Test Checklist

- [ ] **Step 1**: Create booking for 2:00 PM - 3:00 PM (1 hour)
- [ ] **Step 2**: Verify booking shows scheduled times (12:00 PM shown is from your booking)
- [ ] **Step 3**: Start service via API at 1:30 PM (30 min early)
- [ ] **Step 4**: Verify API returns timeline object with actual times
- [ ] **Step 5**: Refresh web UI, see green "Started Early" banner
- [ ] **Step 6**: Verify timeline shows 1:30 PM start, 2:30 PM end
- [ ] **Step 7**: Click "Extend Service Hour"
- [ ] **Step 8**: Verify extension dialog shows early start indicator
- [ ] **Step 9**: Verify extension calculates from 2:30 PM (not 3:00 PM)
- [ ] **Step 10**: Complete extension, verify new end time is 3:30 PM

---

## API Endpoints for Testing

### 1. Start Service (Triggers Timeline Recalculation)
```
POST /api/v2/engagements/:id/start
Body: { "service_day_id": number }
```

### 2. Get Engagement Details
```
GET /api/customers/:customerId/engagements
Returns: { ongoing: [...], upcoming: [...], past: [...] }
```

### 3. Check Extension Availability
```
GET /api/v2/engagements/:id/extension-availability
Returns: { canExtend, currentEndTimeFormatted, availableSlots }
```

### 4. Extend Booking
```
POST /api/v2/engagements/:id/extend
Body: { "extensionHours": number, "newEndTime": string, "additionalAmount": number }
```

### 5. Feature Flag Status
```
GET /api/admin/feature-flags
Returns: List of all feature flags with status
```

---

## Debugging Tips

### Enable Detailed Logging
```bash
# In backend .env file
LOG_LEVEL=debug
NODE_ENV=development
```

### Check Backend Logs
```bash
tail -f services/payments/logs/app.log | grep -i timeline
```

### Check Browser Console
```javascript
// In browser console on booking details page
console.log('Booking data:', bookingData);
console.log('Timeline:', bookingData.actual_start_epoch);
```

### Verify Database State
```sql
-- Check if timeline columns exist
\d engagements;

-- Check timeline data for specific engagement
SELECT 
  engagement_id,
  start_epoch,
  end_epoch,
  actual_start_epoch,
  actual_end_epoch,
  duration_minutes,
  is_timeline_recalculated,
  early_start_minutes,
  task_status
FROM engagements
WHERE engagement_id = YOUR_ID;
```

---

## Next Steps After Successful Test

1. ✅ Verify timeline displays correctly on mobile viewport
2. ✅ Test extension payment flow end-to-end
3. ✅ Test with different early start amounts (5 min, 15 min, 30 min, 60 min)
4. ✅ Test edge cases (start exactly on time, start 1 second early)
5. ✅ Test backwards compatibility (old bookings without timeline data)
6. ✅ Deploy to DEV environment
7. ✅ Run end-to-end tests
8. ✅ User acceptance testing

---

**Remember**: The timeline feature only activates when a service provider starts a service. Until then, the booking will show scheduled times, which is the correct behavior!
