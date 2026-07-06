# Quick Start Guide: ETA & Route Tracking

## For Developers

### Prerequisites

1. **Database**: Engagement must have latitude/longitude set
2. **Backend**: Google Maps API key configured
3. **Frontend**: Tracking service running

### Quick Test (5 minutes)

```bash
# 1. Set engagement coordinates (if not set)
psql $DATABASE_URL -c "
  UPDATE engagements 
  SET latitude = 12.9716, longitude = 77.5946 
  WHERE engagement_id = 353;
"

# 2. Run test script
./test-eta-calculation.sh 353 123

# 3. Open frontend and click "Track Provider"
# Visit: https://servease-innovation.netlify.app
```

---

## For QA/Testers

### Setup New Test Engagement

```sql
-- Create test engagement with coordinates
INSERT INTO engagements (
  customerid, 
  serviceproviderid, 
  address, 
  latitude, 
  longitude,
  booking_type,
  service_type,
  task_status,
  start_date
) VALUES (
  1,                                -- customer ID
  123,                              -- provider ID
  'WeWork MG Road, Bangalore',     -- human-readable address
  12.9716,                          -- booking latitude
  77.5946,                          -- booking longitude
  'ON_DEMAND',
  'Cleaning',
  'SCHEDULED',
  CURRENT_DATE
) RETURNING engagement_id;
```

### Test Scenarios

#### Scenario 1: Basic ETA Calculation
```bash
# Provider at location A, customer at location B
# Should show route and ETA

curl -X POST https://notifications-mjdp.onrender.com/api/tracking/provider/location \
  -H "Content-Type: application/json" \
  -d '{
    "engagement_id": 353,
    "provider_id": 123,
    "latitude": 12.9000,
    "longitude": 77.5500
  }'

# Calculate ETA
curl -X POST https://notifications-mjdp.onrender.com/api/tracking/calculate-eta \
  -H "Content-Type: application/json" \
  -d '{"engagement_id": 353}'
```

#### Scenario 2: Moving Provider
```bash
# Update provider location every 15 seconds (simulates movement)

# Position 1
curl -X POST .../api/tracking/provider/location \
  -d '{"engagement_id": 353, "provider_id": 123, "latitude": 12.9000, "longitude": 77.5500}'

# Wait 15 seconds, Position 2
sleep 15
curl -X POST .../api/tracking/provider/location \
  -d '{"engagement_id": 353, "provider_id": 123, "latitude": 12.9100, "longitude": 77.5600}'

# Wait 15 seconds, Position 3
sleep 15
curl -X POST .../api/tracking/provider/location \
  -d '{"engagement_id": 353, "provider_id": 123, "latitude": 12.9200, "longitude": 77.5700}'
```

#### Scenario 3: Frontend Tracking
1. Login as customer (ID: 1)
2. Navigate to bookings/engagements
3. Find engagement #353
4. Click "Track Provider" button
5. **Verify**:
   - Map loads
   - Provider marker appears (red circle with bike icon)
   - Destination marker appears
   - Blue route line connects them
   - ETA display shows at top
   - ETA counts down every second
   - Route updates every 30 seconds

---

## For Product Managers

### Feature Overview

**What it does**: Shows customer real-time map of provider's location, route, and ETA

**User Experience**:
1. Customer books service for any address (office, home, friend's place)
2. Provider accepts and starts journey
3. Customer clicks "Track Provider" button
4. Map shows:
   - Provider's live location (updates every 15s)
   - Blue route line (optimal path with traffic)
   - ETA countdown (recalculates every 30s)
   - Distance in km

**Business Value**:
- Reduces "Where is my provider?" support calls
- Increases customer satisfaction
- Improves provider accountability
- Enables proactive customer service

### Key Metrics to Track

1. **Tracking Usage**: % of bookings where tracking is activated
2. **Average Tracking Duration**: How long customers watch the map
3. **ETA Accuracy**: Actual arrival time vs predicted ETA
4. **Support Ticket Reduction**: Decrease in "provider location" queries

---

## For Admins

### Data Requirements

**Critical**: Every engagement must have booking location:

```sql
-- Check missing coordinates
SELECT COUNT(*) 
FROM engagements 
WHERE active = true 
  AND (latitude IS NULL OR longitude IS NULL);
```

**If count > 0**, run:

```bash
# Option 1: Run SQL check script
psql $DATABASE_URL -f database/sql/check_engagement_coordinates.sql

# Option 2: Bulk update from customer addresses (only if acceptable)
psql $DATABASE_URL -c "
  UPDATE engagements e
  SET latitude = c.latitude, longitude = c.longitude
  FROM customer c
  WHERE e.customerid = c.customerid
    AND e.latitude IS NULL
    AND c.latitude IS NOT NULL;
"
```

### Monitoring Checklist

- [ ] Google Maps API quota (40k requests/month free tier)
- [ ] Redis memory usage (location cache)
- [ ] Backend error logs (tracking service)
- [ ] ETA calculation success rate
- [ ] Average ETA vs actual arrival time

### Common Admin Tasks

#### 1. Update Engagement Location
```sql
UPDATE engagements 
SET 
  latitude = 12.9716, 
  longitude = 77.5946,
  address = 'WeWork MG Road, Bangalore'
WHERE engagement_id = 353;
```

#### 2. Check Active Tracking Sessions
```sql
SELECT 
  session_id,
  engagement_id,
  customer_id,
  provider_id,
  status,
  started_at
FROM tracking_sessions
WHERE status = 'active'
ORDER BY started_at DESC;
```

#### 3. View Provider Journey Status
```sql
SELECT 
  e.engagement_id,
  e.customerid,
  e.serviceproviderid,
  ets.tracking_status,
  ets.journey_started_at,
  ets.arrived_at
FROM engagements e
JOIN engagement_tracking_status ets ON e.engagement_id = ets.engagement_id
WHERE e.active = true
ORDER BY ets.journey_started_at DESC NULLS LAST
LIMIT 20;
```

---

## Troubleshooting

### Problem: "Track Provider" button disabled

**Check**:
```sql
SELECT 
  engagement_id,
  task_status,
  ets.tracking_status
FROM engagements e
LEFT JOIN engagement_tracking_status ets ON e.engagement_id = ets.engagement_id
WHERE engagement_id = 353;
```

**Solution**: Provider must set status to `en_route`:
```bash
curl -X POST .../api/tracking/provider/start-journey \
  -d '{"engagement_id": 353, "provider_id": 123}'
```

### Problem: No ETA displayed

**Check**: Provider location and engagement coordinates:
```sql
SELECT 
  engagement_id,
  latitude,
  longitude
FROM engagements
WHERE engagement_id = 353;
```

**Solution**: Both must be non-NULL

### Problem: Map shows wrong location

**Cause**: Frontend caching

**Solution**: Hard refresh (Cmd+Shift+R or Ctrl+Shift+R)

---

## Environment Variables

### Backend (.env in tracking service)
```bash
GOOGLE_MAPS_API_KEY=your_key_here
ETA_CACHE_TTL=120
LOCATION_UPDATE_RATE_LIMIT=15000
```

### Frontend (.env.local in servase-ui)
```bash
REACT_APP_GOOGLE_MAPS_API_KEY=your_key_here
REACT_APP_TRACKING_API_URL=https://notifications-mjdp.onrender.com
```

---

## API Endpoints Quick Reference

```
# Provider Endpoints
POST /api/tracking/provider/start-journey
POST /api/tracking/provider/arrived
POST /api/tracking/provider/location
GET  /api/tracking/provider/status/:id

# Customer Endpoints
GET  /api/tracking/availability/:engagementId
POST /api/tracking/session/start
POST /api/tracking/session/stop
GET  /api/tracking/location/:engagementId
POST /api/tracking/calculate-eta
GET  /api/tracking/eta/:engagementId
```

---

## Support Contacts

- **Backend Issues**: Check tracking service logs
- **Frontend Issues**: Check browser console
- **Database Issues**: Run `check_engagement_coordinates.sql`
- **Google Maps Issues**: Check API quota in GCP Console

---

## Success Criteria

✅ Provider location updates every 15 seconds  
✅ ETA recalculates every 30 seconds  
✅ Route displays on map  
✅ ETA countdown accurate within ±5 minutes  
✅ Works on desktop and mobile browsers  
✅ No impact on page load performance  

---

**Last Updated**: 2026-07-06  
**Version**: 1.0  
**Status**: Production Ready ✅
