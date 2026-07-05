-- Backfill Actual End Time for Old Completed Services
-- Run this script to add actual_end_epoch to services completed before the fix

-- Preview what will be updated
SELECT 
  service_day_id,
  engagement_id,
  service_date,
  status,
  actual_start_epoch,
  actual_end_epoch,
  started_at,
  completed_at,
  to_timestamp(actual_start_epoch) AT TIME ZONE 'Asia/Kolkata' as started_at_time,
  completed_at AT TIME ZONE 'Asia/Kolkata' as completed_at_time
FROM service_days
WHERE status = 'COMPLETED'
  AND completed_at IS NOT NULL
  AND actual_end_epoch IS NULL
ORDER BY service_date DESC
LIMIT 20;

-- Update completed services to have actual_end_epoch
-- Uses completed_at as the actual end time (best approximation we have)
UPDATE service_days
SET actual_end_epoch = EXTRACT(EPOCH FROM completed_at)::BIGINT
WHERE status = 'COMPLETED'
  AND completed_at IS NOT NULL
  AND actual_end_epoch IS NULL;

-- Verify the update
SELECT 
  service_day_id,
  engagement_id,
  service_date,
  status,
  to_timestamp(actual_start_epoch) AT TIME ZONE 'Asia/Kolkata' as started_at,
  to_timestamp(actual_end_epoch) AT TIME ZONE 'Asia/Kolkata' as ended_at,
  (actual_end_epoch - actual_start_epoch) / 60 as duration_minutes
FROM service_days
WHERE status = 'COMPLETED'
  AND actual_end_epoch IS NOT NULL
ORDER BY service_date DESC
LIMIT 20;

-- Summary statistics
SELECT 
  COUNT(*) as total_completed,
  COUNT(actual_start_epoch) as has_start_time,
  COUNT(actual_end_epoch) as has_end_time,
  COUNT(CASE WHEN actual_start_epoch IS NOT NULL AND actual_end_epoch IS NOT NULL THEN 1 END) as has_both_times,
  COUNT(CASE WHEN actual_start_epoch IS NULL OR actual_end_epoch IS NULL THEN 1 END) as missing_times
FROM service_days
WHERE status = 'COMPLETED';
