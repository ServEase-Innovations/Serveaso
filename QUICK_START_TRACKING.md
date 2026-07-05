# 🚀 Quick Start: Test Provider Tracking

## 5-Minute Setup

### Step 1: Configure Environment (30 seconds)

```bash
cd apps/servase-ui
cat > .env.dev << 'EOF'
REACT_APP_TRACKING_API_URL=http://localhost:5007/api/tracking
REACT_APP_GOOGLE_MAPS_API_KEY=your_key_here
EOF
```

Replace `your_key_here` with your Google Maps API key.

### Step 2: Start Tracking Service (1 minute)

```bash
# Terminal 1
cd services/notifications/tracking
npm install  # First time only
npm start
# Wait for: "Tracking service listening on port 5007"
```

### Step 3: Start Web App (1 minute)

```bash
# Terminal 2
cd apps/servase-ui
npm run start:dev
# Wait for app to open in browser
```

### Step 4: Create Test Data (1 minute)

Run this SQL to create a test booking for today:

```sql
-- Update an existing engagement or create a test one
UPDATE engagements
SET 
  status = 'provider_on_the_way',
  service_date = CURRENT_DATE,
  start_time = '10:00:00',
  end_time = '12:00:00'
WHERE id = YOUR_ENGAGEMENT_ID;  -- Use a real engagement ID with provider assigned
```

Or if creating new:

```sql
INSERT INTO engagements (
  customer_id,
  serviceproviderid,
  service_type,
  booking_type,
  status,
  service_date,
  start_time,
  end_time,
  address,
  latitude,
  longitude,
  created_at
) VALUES (
  YOUR_CUSTOMER_ID,      -- Customer who will view tracking
  YOUR_PROVIDER_ID,       -- Provider who will be tracked
  'cook',                 -- or 'maid', 'nanny'
  'ON_DEMAND',            -- or 'MONTHLY', 'SHORT_TERM'
  'provider_on_the_way',  -- THIS IS KEY for tracking availability
  CURRENT_DATE,
  '10:00:00',
  '12:00:00',
  '123 Test Street, Delhi',
  28.6139,
  77.2090,
  NOW()
);
```

### Step 5: Test the Feature (2 minutes)

1. **Login** as the customer (use the customer_id from your test data)

2. **Navigate**: Click "Bookings" → "Today" tab

3. **Look for**: Your test booking should appear with provider info

4. **Click**: "Track Provider" button

5. **Result**: 
   - ✅ Full-screen map opens
   - ✅ Destination marker at service address
   - ✅ "Waiting for provider location" message (until provider sends location)

### Step 6: Simulate Provider Location (Optional)

Open browser console and run:

```javascript
// Connect as provider
const socket = io('http://localhost:5007');

socket.emit('join', { providerId: YOUR_PROVIDER_ID });

// Send location update
socket.emit('location-update', {
  engagement_id: YOUR_ENGAGEMENT_ID,
  provider_id: YOUR_PROVIDER_ID,
  latitude: 28.6100,  // Slightly north of destination
  longitude: 77.2090,
  accuracy: 10,
  bearing: 180,  // heading south
  speed: 5,      // 5 m/s = 18 km/h
  timestamp: Date.now()
});

// Send updates every 5 seconds (simulate movement)
setInterval(() => {
  socket.emit('location-update', {
    engagement_id: YOUR_ENGAGEMENT_ID,
    provider_id: YOUR_PROVIDER_ID,
    latitude: 28.6100 + (Math.random() * 0.01 - 0.005),
    longitude: 77.2090 + (Math.random() * 0.01 - 0.005),
    accuracy: 10,
    bearing: 180,
    speed: 5,
    timestamp: Date.now()
  });
}, 5000);
```

Now you should see:
- ✅ Provider marker appears on map
- ✅ ETA displays at top
- ✅ Distance countdown
- ✅ Marker moves with each update

---

## Troubleshooting

### "Track Provider" button not visible
```bash
# Check engagement status
psql -U postgres -d serveaso -c "SELECT id, status, service_date FROM engagements WHERE id = YOUR_ID;"

# Should show:
#  id | status               | service_date
# ----+---------------------+--------------
# 123 | provider_on_the_way | 2026-07-05
```

### Button shows "Tracking not available"
```bash
# Check tracking service logs
# Should see: "Tracking available for engagement 123"
```

### Map doesn't open
```bash
# Check browser console
# Should NOT see: "Google Maps API key missing"
# Should see: "WebSocket connecting to ws://localhost:5007"
```

### Provider location not showing
```bash
# Check tracking service logs
# Should see: "Location update received for engagement 123"
```

---

## Production Checklist

Before deploying to production:

- [ ] Get Google Maps API key (with Maps JS API + Directions API enabled)
- [ ] Set up Redis server
- [ ] Configure PostgreSQL
- [ ] Set environment variables
- [ ] Update engagement status flow in provider app
- [ ] Implement provider location sharing
- [ ] Test end-to-end with real provider
- [ ] Enable HTTPS/WSS for production
- [ ] Set up monitoring and logging

---

## Next: Provider Integration

For providers to send location, implement this in their mobile app:

```typescript
// When provider clicks "Start Journey"
function startLocationSharing(engagementId: number, providerId: number) {
  const socket = io(TRACKING_SERVICE_URL);
  
  socket.emit('join', { providerId });
  
  // Start location updates
  const locationInterval = setInterval(() => {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        socket.emit('location-update', {
          engagement_id: engagementId,
          provider_id: providerId,
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy: position.coords.accuracy,
          bearing: position.coords.heading || 0,
          speed: position.coords.speed || 0,
          timestamp: Date.now()
        });
      },
      (error) => console.error('Location error:', error),
      { 
        enableHighAccuracy: true,
        timeout: 5000,
        maximumAge: 0
      }
    );
  }, 5000); // Every 5 seconds
  
  return () => {
    clearInterval(locationInterval);
    socket.disconnect();
  };
}
```

---

**That's it!** 🎉

You now have live provider tracking working in your app!
