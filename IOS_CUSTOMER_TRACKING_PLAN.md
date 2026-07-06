# iOS Customer Tracking Implementation Plan

## Overview
Add "Track Provider" feature to iOS app, allowing customers to see their provider's real-time location, route, and ETA on a map.

---

## Current State

### ✅ Already Implemented (Provider Side)
- Provider journey tracking
- Location publishing
- Start/Stop journey buttons
- Backend tracking APIs

### ❌ Missing (Customer Side)
- Track Provider button on booking cards
- Live map view with provider location
- ETA display
- Route visualization

---

## Implementation Plan

### Phase 1: Core Tracking Screen

**File**: `src/UserProfile/CustomerTrackingScreen.tsx`

**Features**:
- Full-screen map using `react-native-maps`
- Provider marker with custom icon
- Destination marker
- Live location updates via WebSocket + polling fallback
- Close button to exit tracking

**Dependencies** (already installed):
- `react-native-maps` ✅
- `react-native-geolocation-service` ✅
- `socket.io-client` ✅

---

### Phase 2: Track Provider Button

**File**: `src/UserProfile/TrackProviderButton.tsx`

**Features**:
- Check tracking availability
- Start tracking session
- Open tracking screen
- Show only when provider is "en route"

**Integration Point**:
- Add to `Bookings.tsx` in today's section
- Similar to web's `TrackButton.tsx`

---

### Phase 3: ETA Display

**File**: `src/UserProfile/ETADisplay.tsx`

**Features**:
- Time until arrival (live countdown)
- Distance to destination  
- Traffic indicator
- Color-coded (green/blue/amber)

**Display Locations**:
1. On booking card (compact version)
2. On tracking map (full version)

---

### Phase 4: Route Visualization

**Features**:
- Polyline showing route from provider to customer
- Decode Google Maps polyline format
- Update when ETA recalculates

**Library**: Use `react-native-maps` `<Polyline>` component

---

## File Structure

```
src/
├── UserProfile/
│   ├── CustomerTrackingScreen.tsx    ← NEW: Full tracking screen
│   ├── TrackProviderButton.tsx       ← NEW: Track button component
│   ├── ETADisplay.tsx                ← NEW: ETA display component
│   ├── Bookings.tsx                  ← MODIFY: Add track button
│   └── ...existing files
├── services/
│   ├── trackingService.ts            ← NEW: Customer tracking API calls
│   └── ...existing services
└── ...
```

---

## API Endpoints (Already Available)

```typescript
// Check if tracking available
GET /api/tracking/availability/:engagementId

// Start tracking session
POST /api/tracking/session/start
{
  "engagement_id": 353,
  "customer_id": 1
}

// Get provider location
GET /api/tracking/location/:engagementId

// Calculate ETA
POST /api/tracking/calculate-eta
{
  "engagement_id": 353
}

// WebSocket for live updates
ws://notifications-mjdp.onrender.com
```

---

## Environment Configuration

Add to `src/env.ts` or `.env`:

```typescript
export const TRACKING_API_URL = __DEV__
  ? 'http://localhost:5007'
  : 'https://notifications-mjdp.onrender.com';

export const TRACKING_WS_URL = __DEV__
  ? 'ws://localhost:5007'
  : 'wss://notifications-mjdp.onrender.com';
```

---

## Step-by-Step Implementation

### Step 1: Create Tracking Service

```typescript
// src/services/trackingService.ts
import axios from 'axios';
import { TRACKING_API_URL } from '../env';

const trackingAPI = axios.create({
  baseURL: `${TRACKING_API_URL}/api/tracking`,
  timeout: 10000,
});

export const checkTrackingAvailability = async (engagementId: number) => {
  const response = await trackingAPI.get(`/availability/${engagementId}`);
  return response.data;
};

export const startTrackingSession = async (engagementId: number, customerId: number) => {
  const response = await trackingAPI.post('/session/start', {
    engagement_id: engagementId,
    customer_id: customerId,
  });
  return response.data;
};

export const getLocationUpdate = async (engagementId: number) => {
  const response = await trackingAPI.get(`/location/${engagementId}`);
  return response.data;
};

export const calculateETA = async (engagementId: number) => {
  const response = await trackingAPI.post('/calculate-eta', {
    engagement_id: engagementId,
  });
  return response.data;
};
```

### Step 2: Create Track Provider Button

```typescript
// src/UserProfile/TrackProviderButton.tsx
import React, { useState, useEffect } from 'react';
import { TouchableOpacity, Text, ActivityIndicator } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { checkTrackingAvailability } from '../services/trackingService';

interface TrackProviderButtonProps {
  engagementId: number;
  customerId: number;
  onPress: () => void;
}

export const TrackProviderButton: React.FC<TrackProviderButtonProps> = ({
  engagementId,
  customerId,
  onPress,
}) => {
  const [available, setAvailable] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkAvailability();
  }, [engagementId]);

  const checkAvailability = async () => {
    try {
      const result = await checkTrackingAvailability(engagementId);
      setAvailable(result.available);
    } catch (error) {
      console.error('Failed to check availability:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading || !available) return null;

  return (
    <TouchableOpacity
      onPress={onPress}
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        backgroundColor: '#3B82F6',
        paddingHorizontal: 16,
        paddingVertical: 8,
        borderRadius: 20,
      }}
    >
      <Icon name="map-marker" size={16} color="#fff" />
      <Text style={{ color: '#fff', marginLeft: 6, fontWeight: '600' }}>
        Track Provider
      </Text>
    </TouchableOpacity>
  );
};
```

### Step 3: Create Tracking Screen

```typescript
// src/UserProfile/CustomerTrackingScreen.tsx
import React, { useState, useEffect } from 'react';
import { View, StyleSheet, TouchableOpacity, Text } from 'react-native';
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { getLocationUpdate } from '../services/trackingService';

interface TrackingScreenProps {
  engagementId: number;
  onClose: () => void;
}

export const CustomerTrackingScreen: React.FC<TrackingScreenProps> = ({
  engagementId,
  onClose,
}) => {
  const [providerLocation, setProviderLocation] = useState(null);
  const [region, setRegion] = useState({
    latitude: 12.9716,
    longitude: 77.5946,
    latitudeDelta: 0.05,
    longitudeDelta: 0.05,
  });

  useEffect(() => {
    fetchLocation();
    
    // Poll location every 10 seconds
    const interval = setInterval(fetchLocation, 10000);
    
    return () => clearInterval(interval);
  }, [engagementId]);

  const fetchLocation = async () => {
    try {
      const data = await getLocationUpdate(engagementId);
      if (data?.location) {
        setProviderLocation(data.location);
        setRegion({
          latitude: data.location.latitude,
          longitude: data.location.longitude,
          latitudeDelta: 0.05,
          longitudeDelta: 0.05,
        });
      }
    } catch (error) {
      console.error('Failed to fetch location:', error);
    }
  };

  return (
    <View style={styles.container}>
      <MapView
        provider={PROVIDER_GOOGLE}
        style={styles.map}
        region={region}
      >
        {providerLocation && (
          <Marker
            coordinate={{
              latitude: providerLocation.latitude,
              longitude: providerLocation.longitude,
            }}
            title="Service Provider"
          >
            <View style={styles.providerMarker}>
              <Icon name="moped" size={24} color="#fff" />
            </View>
          </Marker>
        )}
      </MapView>

      <TouchableOpacity style={styles.closeButton} onPress={onClose}>
        <Icon name="close" size={24} color="#333" />
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  map: {
    ...StyleSheet.absoluteFillObject,
  },
  closeButton: {
    position: 'absolute',
    top: 50,
    right: 20,
    backgroundColor: '#fff',
    borderRadius: 25,
    width: 50,
    height: 50,
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
  },
  providerMarker: {
    backgroundColor: '#EF4444',
    borderRadius: 30,
    width: 60,
    height: 60,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
```

### Step 4: Integrate into Bookings

```typescript
// In Bookings.tsx, add to today's booking card render:

import { TrackProviderButton } from './TrackProviderButton';
import { CustomerTrackingScreen } from './CustomerTrackingScreen';

// Add state
const [trackingVisible, setTrackingVisible] = useState(false);
const [trackingEngagementId, setTrackingEngagementId] = useState<number | null>(null);

// In render method for today's bookings:
{viewTab === 'today' && (
  <TrackProviderButton
    engagementId={item.id}
    customerId={effectiveCustomerId}
    onPress={() => {
      setTrackingEngagementId(item.id);
      setTrackingVisible(true);
    }}
  />
)}

// Add modal at bottom of component:
<RNModal
  visible={trackingVisible}
  animationType="slide"
  onRequestClose={() => setTrackingVisible(false)}
>
  {trackingEngagementId && (
    <CustomerTrackingScreen
      engagementId={trackingEngagementId}
      onClose={() => setTrackingVisible(false)}
    }
  />
</RNModal>
```

---

## Testing Checklist

### Local Testing

- [ ] Start tracking backend: `cd services/notifications/tracking && npm start`
- [ ] Update `.env` with local URL
- [ ] Run iOS app: `npm run ios`
- [ ] Provider starts journey
- [ ] Customer sees "Track Provider" button
- [ ] Customer opens tracking map
- [ ] Provider location shows on map
- [ ] Location updates every 10 seconds

### Production Testing

- [ ] Update `.env` with production URL
- [ ] Deploy app to TestFlight
- [ ] Test with real bookings
- [ ] Verify location accuracy
- [ ] Test on different iOS versions

---

## Next Steps After Basic Implementation

1. **Add ETA Display**
   - Show time until arrival
   - Distance indicator
   - Traffic status

2. **Add Route Polyline**
   - Show path from provider to customer
   - Decode Google Maps polyline
   - Update with ETA recalculation

3. **Add Compact ETA on Booking Card**
   - Small badge showing ETA
   - Live countdown
   - Color-coded status

4. **Improve UX**
   - WebSocket for real-time updates
   - Custom map markers (bike icon)
   - Smooth marker animations
   - Pull to refresh

5. **Add Notifications**
   - Alert when provider is 5 min away
   - Push notification when journey starts
   - Arrival notification

---

## Estimated Timeline

- **Step 1-2**: Tracking Service + Button (2-3 hours)
- **Step 3**: Basic Tracking Screen (3-4 hours)
- **Step 4**: Integration (1-2 hours)
- **Testing & Polish**: (2-3 hours)

**Total**: 8-12 hours for basic implementation

---

## References

- Web Implementation: `apps/servase-ui/src/components/Tracking/`
- Backend APIs: `services/notifications/tracking/`
- Provider Tracking: `apps/servease-ios/src/ServiceProvider/JourneyTrackingButton.tsx`
- React Native Maps Docs: https://github.com/react-native-maps/react-native-maps

---

**Status**: Ready to Implement
**Priority**: High
**Dependencies**: All backend APIs ready ✅
