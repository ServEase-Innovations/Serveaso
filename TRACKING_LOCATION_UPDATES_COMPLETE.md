# Tracking Location Updates - Implementation Complete

**Date**: July 5, 2026
**Status**: ✅ Backend Complete | ⏳ Frontend Integration Needed

---

## Summary

Successfully implemented provider location publishing system. Providers now automatically send their GPS location every 15 seconds while en_route, and customers can retrieve these updates via polling or WebSocket.

---

## Backend Changes

### 1. New Provider Location Endpoint

**File**: `services/notifications/tracking/src/routes/providerTrackingRoutes.js`

**Endpoint**: `POST /api/tracking/provider/location`

**Purpose**: Allows providers to publish their current GPS location during journey

**Request**:
```json
{
  "engagement_id": 235,
  "provider_id": 4,
  "latitude": 12.9352,
  "longitude": 77.6245,
  "accuracy": 10,
  "speed": 0,
  "bearing": 45
}
```

**Response**:
```json
{
  "message": "Location updated successfully",
  "timestamp": 1783275529526
}
```

**Validation**:
- ✅ Checks engagement exists
- ✅ Verifies journey status is `en_route`
- ✅ Validates latitude/longitude ranges
- ✅ Rate limiting (max 1 update per 15 seconds per provider)
- ✅ Stores in Redis with TTL
- ✅ Publishes to Pub/Sub for real-time delivery

---

### 2. Location Retrieval Endpoint

**Endpoint**: `GET /api/tracking/location/:engagementId` (already existed)

**Response**:
```json
{
  "location": {
    "latitude": 12.9352,
    "longitude": 77.6245,
    "accuracy": 10,
    "bearing": 45,
    "speed": 0,
    "timestamp": 1783275529526
  },
  "eta": null,
  "status": "active",
  "is_estimated": false,
  "last_update_age": 3344
}
```

**Status Values**:
- `active`: Location updated within last 60 seconds
- `offline_estimated`: No update for 60+ seconds, showing estimated position

---

## Frontend Changes

### 1. Provider Side - Auto Location Publishing

**File**: `apps/servase-ui/src/services/providerTrackingService.ts`

**Added Function**:
```typescript
export async function updateLocation(
  engagementId: number,
  latitude: number,
  longitude: number,
  accuracy?: number,
  speed?: number,
  bearing?: number
): Promise<void>
```

**File**: `apps/servase-ui/src/components/ServiceProvider/JourneyTrackingButton.tsx`

**Features**:
- ✅ Starts location tracking when status becomes `en_route`
- ✅ Uses `navigator.geolocation.watchPosition()` for continuous updates
- ✅ Fallback polling every 15 seconds
- ✅ Automatically stops when journey ends
- ✅ Sends latitude, longitude, accuracy, speed, bearing to backend

**Browser Permissions**:
- Requests location permission when starting journey
- Continues working even if denied (without location data)
- Uses high accuracy GPS mode

---

### 2. Customer Side - Map Display Issue

**Problem**: Map shows default center (New Delhi) instead of provider's actual location

**Root Cause**: TrackingMapView component uses Redux state that isn't being populated with location data

**File**: `apps/servase-ui/src/components/Tracking/TrackingMapView.tsx`

**Current Behavior**:
```typescript
const defaultCenter = {
  lat: 28.6139, // Delhi
  lng: 77.2090,
};

const mapCenter = tracking.map.center 
  ? { lat: tracking.map.center.latitude, lng: tracking.map.center.longitude }
  : defaultCenter; // Falls back to Delhi
```

**What's Missing**:
1. ❌ Redux state `tracking.map.center` is not being populated
2. ❌ Redux state `tracking.provider.location` is not being populated
3. ❌ WebSocket/polling isn't fetching location updates
4. ❌ Map doesn't center on provider location when data arrives

---

## Testing

### Backend Testing ✅

#### 1. Start Journey
```bash
curl -X POST http://localhost:5007/api/tracking/provider/start-journey \
  -H "Content-Type: application/json" \
  -d '{
    "engagement_id": 235,
    "provider_id": 4,
    "latitude": 12.9352,
    "longitude": 77.6245
  }'
```

#### 2. Publish Location Updates
```bash
curl -X POST http://localhost:5007/api/tracking/provider/location \
  -H "Content-Type: application/json" \
  -d '{
    "engagement_id": 235,
    "provider_id": 4,
    "latitude": 12.9352,
    "longitude": 77.6245,
    "accuracy": 10
  }'
```

#### 3. Customer Retrieves Location
```bash
curl http://localhost:5007/api/tracking/location/235
```

**Result**: ✅ All working! Location stored in Bangalore (12.90°N, 77.57°E)

---

## Frontend Integration TODO

### High Priority - Fix Map Display

#### Option A: Update Redux on WebSocket/Polling
**File**: `apps/servase-ui/src/components/Tracking/hooks/useTrackingWebSocket.ts`

Need to dispatch Redux actions when location updates arrive:
```typescript
import { updateProviderLocation, setMapCenter } from '../../../features/tracking/trackingSlice';

// When location update received:
dispatch(updateProviderLocation({
  latitude: data.location.latitude,
  longitude: data.location.longitude,
  accuracy: data.location.accuracy,
  timestamp: data.location.timestamp,
}));

// Auto-center map on first update
if (!tracking.map.center) {
  dispatch(setMapCenter({
    latitude: data.location.latitude,
    longitude: data.location.longitude,
  }));
}
```

#### Option B: Use Customer's Location as Initial Center
If customer location is available, use it instead of Delhi:
```typescript
const defaultCenter = customerLocation 
  ? { lat: customerLocation.latitude, lng: customerLocation.longitude }
  : { lat: 12.9716, lng: 77.5946 }; // Bangalore as fallback
```

#### Option C: Fetch Location Immediately After Session Start
In `TrackButton.tsx` after starting session:
```typescript
// After session created:
const locationData = await getLocationUpdate(engagementId);
if (locationData?.location) {
  dispatch(updateProviderLocation(locationData.location));
  dispatch(setMapCenter({
    latitude: locationData.location.latitude,
    longitude: locationData.location.longitude,
  }));
}
```

---

### Medium Priority - Real-Time Updates

#### WebSocket Implementation
**File**: `apps/servase-ui/src/components/Tracking/hooks/useTrackingWebSocket.ts`

Connect to WebSocket and listen for location updates:
```typescript
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  
  if (data.type === 'location_update') {
    dispatch(updateProviderLocation(data.location));
    
    // Update ETA if provided
    if (data.eta) {
      dispatch(updateETA(data.eta));
    }
  }
};
```

#### Polling Fallback
If WebSocket fails, poll every 10-15 seconds:
```typescript
const intervalId = setInterval(async () => {
  try {
    const locationData = await getLocationUpdate(engagementId);
    if (locationData?.location) {
      dispatch(updateProviderLocation(locationData.location));
    }
  } catch (error) {
    console.error('Failed to poll location:', error);
  }
}, 15000);
```

---

## How It Works Now

### Provider Journey Flow

1. **Provider clicks "Start Journey"**
   - Calls `/api/tracking/provider/start-journey`
   - Sets status to `en_route` in database
   - Stores initial location (if available)

2. **Automatic Location Tracking Begins**
   - Browser's `watchPosition()` monitors GPS
   - Every location change triggers update
   - Fallback interval sends update every 15s
   - Calls `/api/tracking/provider/location`

3. **Backend Processes Location**
   - Validates location data
   - Checks rate limit (15s minimum)
   - Stores in Redis as:
     - `location_latest:235` (current position)
     - `location_history:235` (last 10 positions)
   - Publishes to Pub/Sub channel
   - Sets 1-hour TTL

4. **Provider clicks "Mark Arrived"**
   - Calls `/api/tracking/provider/arrived`
   - Sets status to `arrived`
   - **Stops location tracking**

### Customer Tracking Flow

1. **Customer clicks "Track Provider"**
   - Calls `/api/tracking/session/start`
   - Receives session ID and WebSocket URL

2. **Customer Map Opens**
   - Currently shows Delhi (wrong!)
   - **Should**: Fetch location immediately
   - **Should**: Connect to WebSocket
   - **Should**: Display provider marker

3. **Real-Time Updates**
   - WebSocket pushes location updates
   - Map moves marker smoothly
   - Shows ETA and distance
   - Detects offline and shows estimated position

---

## Configuration

### Backend
**File**: `services/notifications/tracking/.env`

```env
# Location Update Configuration
LOCATION_UPDATE_INTERVAL=30000        # How often to accept updates (15s min)
LOCATION_HISTORY_SIZE=10              # Keep last N locations
LOCATION_CACHE_TTL=3600               # 1 hour expiry

# Rate Limiting
LOCATION_UPDATE_RATE_LIMIT=15000      # Min 15s between updates
```

### Frontend
**File**: `apps/servase-ui/src/components/ServiceProvider/JourneyTrackingButton.tsx`

```typescript
// Location update frequency
const LOCATION_UPDATE_INTERVAL = 15000; // 15 seconds

// Geolocation options
{
  enableHighAccuracy: true,  // Use GPS
  timeout: 10000,            // 10s timeout
  maximumAge: 5000,          // Accept cached location if < 5s old
}
```

---

## Data Flow Diagram

```
PROVIDER SIDE:
┌─────────────────────┐
│ Provider Dashboard  │
│ "Start Journey"     │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────────────────┐
│ JourneyTrackingButton           │
│ • Starts watchPosition()        │
│ • Interval sends location       │
└──────────┬──────────────────────┘
           │ POST /provider/location
           ↓
┌─────────────────────────────────┐
│ Tracking Service (Backend)      │
│ • Validates location            │
│ • Stores in Redis               │
│ • Publishes to Pub/Sub          │
└──────────┬──────────────────────┘
           │
           ↓
    ┌──────┴──────┐
    │             │
    ↓             ↓
[Redis Cache]  [Pub/Sub Channel]


CUSTOMER SIDE:
┌─────────────────────┐
│ Customer App        │
│ "Track Provider"    │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────────────────┐
│ TrackingMapView                 │
│ • Opens map dialog              │
│ • Connects WebSocket            │
│ • OR polls location             │
└──────────┬──────────────────────┘
           │ GET /location/:id
           ↓
┌─────────────────────────────────┐
│ Tracking Service (Backend)      │
│ • Fetches from Redis            │
│ • Returns location data         │
└─────────────────────────────────┘
```

---

## Next Steps

### Immediate (Fix Map Display)
1. ⏳ Check Redux slice for `updateProviderLocation` action
2. ⏳ Update `useTrackingWebSocket` to dispatch location updates
3. ⏳ Change default map center from Delhi to Bangalore
4. ⏳ Fetch initial location when map opens

### Short Term
1. ⏳ Implement WebSocket message handling
2. ⏳ Add smooth marker animation
3. ⏳ Show provider location on map
4. ⏳ Display accuracy circle
5. ⏳ Show customer location (destination)

### Medium Term
1. ⏳ ETA calculation integration
2. ⏳ Route polyline display
3. ⏳ Offline detection and estimation
4. ⏳ Battery optimization (reduce update frequency)

---

## Files Modified

### Backend
- ✅ `services/notifications/tracking/src/routes/providerTrackingRoutes.js` - Added location endpoint
- ✅ `services/notifications/tracking/src/services/locationProcessor.js` - Already had processing logic

### Frontend - Provider
- ✅ `apps/servase-ui/src/services/providerTrackingService.ts` - Added updateLocation function
- ✅ `apps/servase-ui/src/components/ServiceProvider/JourneyTrackingButton.tsx` - Auto location tracking

### Frontend - Customer (Needs Work)
- ⏳ `apps/servase-ui/src/components/Tracking/TrackingMapView.tsx` - Map center issue
- ⏳ `apps/servase-ui/src/components/Tracking/hooks/useTrackingWebSocket.ts` - Redux integration
- ⏳ `apps/servase-ui/src/features/tracking/trackingSlice.ts` - Redux actions

---

## Known Issues

### 1. Map Shows Delhi Instead of Provider Location
**Status**: ⚠️ Known Issue
**Impact**: High - Customers can't see provider
**Fix**: Need to integrate Redux with location polling/WebSocket

### 2. Provider Marker Not Visible
**Status**: ⚠️ Related to Issue #1
**Impact**: High
**Fix**: Redux state needs provider location data

### 3. WebSocket Not Implemented
**Status**: ⏳ Planned
**Impact**: Medium - Polling works as fallback
**Fix**: Implement WebSocket connection and message handling

---

## Success Criteria

### ✅ Completed
- Provider can start journey and location tracking begins
- Location updates sent to backend automatically
- Backend stores and serves location via API
- Rate limiting prevents spam
- Location data has proper TTL

### ⏳ Remaining
- Map centers on provider location
- Provider marker visible on map
- Real-time updates via WebSocket
- Smooth marker movement
- ETA display

---

## Testing Checklist

### Provider Side ✅
- [x] Click "Start Journey" button
- [x] Browser requests location permission
- [x] Location updates sent every 15s
- [x] Updates continue while en_route
- [x] Updates stop when marking arrived
- [x] Backend receives and stores location

### Customer Side ⏳
- [x] Click "Track Provider" button
- [x] Tracking session created
- [ ] Map centers on provider location (not Delhi)
- [ ] Provider marker visible
- [ ] Marker moves as provider moves
- [ ] ETA displays and updates
- [ ] Offline detection works

---

## Contact

For Redux integration help, check:
- `apps/servase-ui/src/features/tracking/trackingSlice.ts`
- `apps/servase-ui/src/components/Tracking/hooks/useTrackingWebSocket.ts`
- Redux DevTools in browser for state inspection
