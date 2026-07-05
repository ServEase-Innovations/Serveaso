-- Test Data Script: Add Actual Timeline to Existing Booking
-- This simulates what would happen if booking #212 had timeline recalculation

-- For Booking #212 (Home Cook, June 14, 2026, 12:00 PM - 1:00 PM)

-- Scenario: Service started 20 minutes early (11:40 AM instead of 12:00 PM)
-- Duration: 60 minutes
-- Expected actual end: 12:40 PM (instead of 1:00 PM)

-- First, let's see the current data
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
WHERE engagement_id = 212;

-- Now update with simulated actual times
-- Assuming start_epoch is for 12:00 PM on June 14, 2026
-- We'll make it start 20 minutes early (11:40 AM)

UPDATE engagements
SET 
  actual_start_epoch = start_epoch - (20 * 60),  -- 20 minutes earlier
  actual_end_epoch = start_epoch - (20 * 60) + (60 * 60),  -- Start + 60 min duration
  duration_minutes = 60,
  is_timeline_recalculated = true,
  early_start_minutes = 20
WHERE engagement_id = 212;

-- Verify the update
SELECT 
  engagement_id,
  to_timestamp(start_epoch) AT TIME ZONE 'Asia/Kolkata' as scheduled_start,
  to_timestamp(end_epoch) AT TIME ZONE 'Asia/Kolkata' as scheduled_end,
  to_timestamp(actual_start_epoch) AT TIME ZONE 'Asia/Kolkata' as actual_start,
  to_timestamp(actual_end_epoch) AT TIME ZONE 'Asia/Kolkata' as actual_end,
  duration_minutes,
  is_timeline_recalculated,
  early_start_minutes
FROM engagements
WHERE engagement_id = 212;

-- Expected result:
-- scheduled_start: 2026-06-14 12:00:00
-- scheduled_end:   2026-06-14 13:00:00 (1:00 PM)
-- actual_start:    2026-06-14 11:40:00 (20 min early)
-- actual_end:      2026-06-14 12:40:00 (11:40 AM + 60 min)
-- is_timeline_recalculated: true
-- early_start_minutes: 20

-- After running this, refresh the web UI and you should see:
-- ✅ "Service Started Early" green banner
-- ✅ "Started At: 11:40 AM" (in green with checkmark)
-- ✅ "Ended At: 12:40 PM" (in green with checkmark)
-- ✅ "Scheduled: 12:00 PM" shown below actual time
-- ✅ Badge: "Started 20 min early"
