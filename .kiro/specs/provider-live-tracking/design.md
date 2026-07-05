# Service Provider Live Tracking - Technical Design

## 1. System Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client Layer                              │
├──────────────────────────┬──────────────────────────────────────┤
│   Web App (React)        │   iOS App (React Native)             │
│   - Tracking UI          │   - Tracking UI                      │
│   - Map Component        │   - Map Component                    │
│   - WebSocket Client     │   - WebSocket Client                 │
│   - State Management     │   - State Management                 │
└──────────────┬───────────┴──────────────┬───────────────────────┘
               │                          │
               │      HTTPS/WSS           │
               │                          │
┌──────────────┴──────────────────────────┴───────────────────────┐
│                     API Gateway / Load Balancer                  │
└──────────────┬──────────────────────────┬───────────────────────┘
               │                          │
     ┌─────────┴─────────┐    ┌──────────┴──────────┐
     │  REST API Server  │    │  WebSocket Server   │
     │  (Node.js/Express)│    │  (Socket.io/ws)     │
     └─────────┬─────────┘    └──────────┬──────────┘
               │                          │
               │    ┌─────────────────────┴─────────┐
               │    │   Redis Pub/Sub              │
               │    │   - Location updates         │
               │    │   - Connection management    │
               │    └─────────────┬────────────────┘
               │                  │
     ┌─────────┴──────────────────┴─────────────────┐
     │         Tracking Service                      │
     │  - Location processing                        │
     │  - ETA calculation                           │
     │  - Position estimation                        │
     │  - Team tracking logic                       │
     └─────────┬────────────────────────────────────┘
               │
     ┌─────────┴──────────────────────────────────────┐
     │         Database Layer                         │
     ├────────────────────┬───────────────────────────┤
     │  PostgreSQL        │   Redis Cache             │
     │  - Engagements     │   - Active sessions       │
     │  - Providers       │   - Location updates      │
     │  - Tracking logs   │   - ETA cache            │
     └────────────────────┴───────────────────────────┘
               │
     ┌─────────┴──────────────────────────────────────┐
     │         External Services                      │
     ├────────────────────┬───────────────────────────┤
     │  Google Maps API   │   Messaging Service       │
     │  - Directions API  │   - Push notifications    │
     │  - Maps rendering  │   - Chat integration      │
     └────────────────────┴───────────────────────────┘
```

### 1.2 Component Responsibilities

**Client Layer (Web & iOS):**
- Render tracking UI and map
- Manage WebSocket connections
- Handle location updates and animations
- Calculate and display client-side ETA updates
- Manage offline/online transitions

**API Gateway:**
- Route requests to appropriate services
- Handle authentication/authorization
- Rate limiting and throttling
- Load balancing across multiple servers

**REST API Server:**
- Tracking session management (start/stop)
- Tracking availability checks
- Provider status updates
- Historical data queries (limited to active sessions)

**WebSocket Server:**
- Real-time location update streaming
- Connection lifecycle management
- Heartbeat/ping-pong for connection health
- Fallback to polling when WebSocket unavailable

**Redis Pub/Sub:**
- Distribute location updates across WebSocket server instances
- Cache active tracking sessions
- Store recent location updates for reconnections
- Manage connection state across instances

**Tracking Service:**
- Process incoming location data from providers
- Calculate ETA using routing APIs
- Implement position estimation algorithm
- Handle team tracking logic
- Enforce privacy rules (auto-purge)

**Database Layer:**
- PostgreSQL: Persistent storage for engagements, providers
- Redis: Fast cache for active sessions, real-time data
- Minimal location history (last 10 updates only, purged on completion)

**External Services:**
- Google Maps Directions API for ETA calculation
- Google Maps JavaScript API / React Native Maps for rendering
- Existing messaging service for in-app chat integration

---

## 2. Data Models

### 2.1 Location Update Payload

```typescript
interface LocationUpdate {
  provider_id: number;
  engagement_id: number;
  latitude: number;          // Decimal degrees
  longitude: number;         // Decimal degrees
  accuracy: number;          // Meters
  bearing: number;           // Degrees (0-360, 0=North)
  speed: number;             // Meters per second
  timestamp: number;         // Unix epoch (milliseconds)
  is_team_lead?: boolean;
  team_member_count?: number | null;
}
```

### 2.2 Tracking Session

```typescript
interface TrackingSession {
  session_id: string;
  engagement_id: number;
  customer_id: number;
  provider_id: number;
  status: 'active' | 'offline_estimated' | 'completed';
  started_at: number;        // Unix epoch
  last_update_at: number;    // Unix epoch
  destination: {
    latitude: number;
    longitude: number;
    address: string;
  };
  is_team: boolean;
  team_data?: {
    lead_provider_id: number;
    member_ids: number[];
    member_count: number;
  };
}
```

### 2.3 ETA Calculation Result

```typescript
interface ETAResult {
  engagement_id: number;
  distance_meters: number;
  duration_seconds: number;
  eta_range: {
    min_seconds: number;     // Lower bound of ETA range
    max_seconds: number;     // Upper bound of ETA range
  };
  traffic_aware: boolean;
  calculated_at: number;     // Unix epoch
  confidence: 'high' | 'medium' | 'low';
  route_polyline?: string;   // Encoded polyline (optional)
}
```

### 2.4 Provider Status

```typescript
interface ProviderStatus {
  provider_id: number;
  engagement_id: number;
  status: 'not_started' | 'en_route' | 'arrived' | 'in_progress' | 'completed';
  tracking_available: boolean;
  tracking_reason?: string;  // e.g., "Provider hasn't started journey"
  last_known_location?: {
    latitude: number;
    longitude: number;
    timestamp: number;
  };
}
```

### 2.5 Estimated Position (Offline Mode)

```typescript
interface EstimatedPosition {
  latitude: number;
  longitude: number;
  estimated: true;
  confidence: number;        // 0-1, decreases over time
  based_on_update_at: number; // Unix epoch of last real update
  seconds_since_update: number;
  estimation_method: 'linear_projection' | 'route_based' | 'last_known';
}
```

---

## 3. API Design

### 3.1 REST API Endpoints

#### GET /api/tracking/availability/:engagementId
Check if tracking is available for an engagement.

**Response:**
```json
{
  "available": true,
  "provider_status": "en_route",
  "reason": null,
  "is_team": false,
  "team_data": null
}
```

#### POST /api/tracking/session/start
Start a tracking session for a customer.

**Request:**
```json
{
  "engagement_id": 353,
  "customer_id": 1
}
```

**Response:**
```json
{
  "session_id": "sess_abc123",
  "websocket_url": "wss://api.servease.com/tracking/ws",
  "polling_url": "/api/tracking/location/353",
  "session_token": "eyJhbGc..."
}
```

#### POST /api/tracking/session/stop
Stop a tracking session.

**Request:**
```json
{
  "session_id": "sess_abc123"
}
```

#### GET /api/tracking/location/:engagementId
Polling endpoint for location updates (fallback when WebSocket unavailable).

**Response:**
```json
{
  "location": {
    "latitude": 28.5355,
    "longitude": 77.3910,
    "accuracy": 15,
    "bearing": 180,
    "speed": 8.5,
    "timestamp": 1704715200000
  },
  "eta": {
    "distance_meters": 2500,
    "duration_seconds": 420,
    "eta_range": {
      "min_seconds": 360,
      "max_seconds": 480
    },
    "confidence": "high"
  },
  "status": "active",
  "is_estimated": false
}
```

#### GET /api/tracking/eta/:engagementId
Get current ETA calculation.

**Response:**
```json
{
  "distance_meters": 2500,
  "duration_seconds": 420,
  "eta_range": {
    "min_seconds": 360,
    "max_seconds": 480
  },
  "traffic_aware": true,
  "calculated_at": 1704715200000,
  "confidence": "high"
}
```

### 3.2 WebSocket Protocol

#### Connection
```
ws://api.servease.com/tracking/ws?token=<session_token>
```

#### Client → Server Messages

**Subscribe to Engagement:**
```json
{
  "type": "subscribe",
  "engagement_id": 353
}
```

**Heartbeat (Ping):**
```json
{
  "type": "ping"
}
```

**Unsubscribe:**
```json
{
  "type": "unsubscribe",
  "engagement_id": 353
}
```

#### Server → Client Messages

**Location Update:**
```json
{
  "type": "location_update",
  "engagement_id": 353,
  "location": {
    "latitude": 28.5355,
    "longitude": 77.3910,
    "accuracy": 15,
    "bearing": 180,
    "speed": 8.5,
    "timestamp": 1704715200000
  },
  "eta": {
    "duration_seconds": 420,
    "eta_range": { "min_seconds": 360, "max_seconds": 480 }
  }
}
```

**Status Change:**
```json
{
  "type": "status_change",
  "engagement_id": 353,
  "old_status": "en_route",
  "new_status": "arrived"
}
```

**Connection Lost (Provider Offline):**
```json
{
  "type": "connection_lost",
  "engagement_id": 353,
  "last_update_at": 1704715200000,
  "estimated_position": {
    "latitude": 28.5360,
    "longitude": 77.3915,
    "confidence": 0.8,
    "seconds_since_update": 90
  }
}
```

**Heartbeat Response (Pong):**
```json
{
  "type": "pong"
}
```

**Error:**
```json
{
  "type": "error",
  "code": "TRACKING_UNAVAILABLE",
  "message": "Provider has not started journey"
}
```

---

## 4. Frontend Architecture

### 4.1 Component Structure (React - Web & React Native - iOS)

```
TrackingFeature/
├── components/
│   ├── TrackButton.tsx              # Button to open tracking
│   ├── TrackingMapView.tsx          # Full-screen map container
│   ├── ProviderMarker.tsx           # Provider location marker
│   ├── DestinationMarker.tsx        # Service address marker
│   ├── ETADisplay.tsx               # ETA card/banner
│   ├── OfflineBanner.tsx            # Connection lost indicator
│   ├── MessageButton.tsx            # Quick message button
│   └── TrackingControls.tsx         # Zoom, recenter controls
├── hooks/
│   ├── useTrackingSession.ts        # Manages session lifecycle
│   ├── useLocationUpdates.ts        # WebSocket/polling for updates
│   ├── usePositionEstimation.ts     # Offline estimation logic
│   ├── useMapControls.ts            # Map interaction handlers
│   └── useETACalculation.ts         # Client-side ETA updates
├── services/
│   ├── trackingAPI.ts               # REST API calls
│   ├── websocketClient.ts           # WebSocket connection management
│   ├── mapProvider.ts               # Google Maps / Mapbox integration
│   └── positionEstimator.ts         # Estimation algorithm
├── store/
│   ├── trackingSlice.ts             # Redux slice (or Context)
│   └── selectors.ts                 # State selectors
└── utils/
    ├── coordinates.ts               # Lat/lng calculations
    ├── etaFormatter.ts              # ETA display formatting
    └── markerAnimations.ts          # Smooth marker movement
```

### 4.2 State Management

**Tracking State (Redux/Context):**
```typescript
interface TrackingState {
  session: {
    id: string | null;
    engagementId: number | null;
    isActive: boolean;
    startedAt: number | null;
  };
  connection: {
    status: 'disconnected' | 'connecting' | 'connected' | 'reconnecting';
    transport: 'websocket' | 'polling' | null;
    lastHeartbeat: number | null;
  };
  provider: {
    location: LocationUpdate | null;
    status: 'not_started' | 'en_route' | 'arrived' | 'in_progress' | 'completed';
    isOnline: boolean;
    estimatedPosition: EstimatedPosition | null;
  };
  destination: {
    latitude: number;
    longitude: number;
    address: string;
  };
  eta: ETAResult | null;
  team: {
    isTeam: boolean;
    leadProviderId: number | null;
    members: Array<{ id: number; name: string }>;
  };
  map: {
    center: { latitude: number; longitude: number } | null;
    zoom: number;
    isAutoCenter: boolean;
  };
  ui: {
    isMapVisible: boolean;
    error: string | null;
    isLoading: boolean;
  };
}
```

### 4.3 WebSocket Client Implementation

```typescript
class TrackingWebSocketClient {
  private ws: WebSocket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private heartbeatInterval: NodeJS.Timeout | null = null;
  
  connect(sessionToken: string, engagementId: number) {
    const wsUrl = `${WS_BASE_URL}?token=${sessionToken}`;
    this.ws = new WebSocket(wsUrl);
    
    this.ws.onopen = () => {
      this.subscribe(engagementId);
      this.startHeartbeat();
      this.reconnectAttempts = 0;
    };
    
    this.ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      this.handleMessage(message);
    };
    
    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
    
    this.ws.onclose = () => {
      this.stopHeartbeat();
      this.attemptReconnect(sessionToken, engagementId);
    };
  }
  
  private subscribe(engagementId: number) {
    this.send({ type: 'subscribe', engagement_id: engagementId });
  }
  
  private startHeartbeat() {
    this.heartbeatInterval = setInterval(() => {
      this.send({ type: 'ping' });
    }, 30000); // 30 seconds
  }
  
  private stopHeartbeat() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }
  }
  
  private attemptReconnect(sessionToken: string, engagementId: number) {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
      setTimeout(() => this.connect(sessionToken, engagementId), delay);
    } else {
      // Fall back to polling
      this.switchToPolling(engagementId);
    }
  }
  
  private switchToPolling(engagementId: number) {
    // Notify app to use polling fallback
    store.dispatch(setConnectionTransport('polling'));
  }
  
  send(message: object) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    }
  }
  
  disconnect() {
    this.stopHeartbeat();
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}
```

---

## 5. Position Estimation Algorithm

When the provider goes offline, estimate their position based on last known data:

```typescript
function estimatePosition(
  lastLocation: LocationUpdate,
  elapsedSeconds: number
): EstimatedPosition {
  const MAX_ESTIMATION_TIME = 600; // 10 minutes
  
  if (elapsedSeconds > MAX_ESTIMATION_TIME) {
    return {
      ...lastLocation,
      estimated: true,
      confidence: 0,
      based_on_update_at: lastLocation.timestamp,
      seconds_since_update: elapsedSeconds,
      estimation_method: 'last_known'
    };
  }
  
  // Calculate distance traveled based on speed and time
  const distanceMeters = lastLocation.speed * elapsedSeconds;
  
  // Convert bearing to radians
  const bearingRad = (lastLocation.bearing * Math.PI) / 180;
  
  // Earth's radius in meters
  const EARTH_RADIUS = 6371000;
  
  // Calculate new position using haversine formula
  const lat1 = (lastLocation.latitude * Math.PI) / 180;
  const lon1 = (lastLocation.longitude * Math.PI) / 180;
  
  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(distanceMeters / EARTH_RADIUS) +
    Math.cos(lat1) * Math.sin(distanceMeters / EARTH_RADIUS) * Math.cos(bearingRad)
  );
  
  const lon2 = lon1 + Math.atan2(
    Math.sin(bearingRad) * Math.sin(distanceMeters / EARTH_RADIUS) * Math.cos(lat1),
    Math.cos(distanceMeters / EARTH_RADIUS) - Math.sin(lat1) * Math.sin(lat2)
  );
  
  // Confidence decreases over time
  const confidence = Math.max(0, 1 - (elapsedSeconds / MAX_ESTIMATION_TIME));
  
  return {
    latitude: (lat2 * 180) / Math.PI,
    longitude: (lon2 * 180) / Math.PI,
    estimated: true,
    confidence,
    based_on_update_at: lastLocation.timestamp,
    seconds_since_update: elapsedSeconds,
    estimation_method: 'linear_projection'
  };
}
```

---

## 6. ETA Calculation Service

### 6.1 Backend ETA Calculator

```typescript
class ETACalculator {
  private directionsAPI: GoogleMapsDirectionsAPI;
  private cache: RedisCache;
  
  async calculateETA(
    fromLocation: { lat: number; lng: number },
    toLocation: { lat: number; lng: number },
    engagementId: number
  ): Promise<ETAResult> {
    // Check cache first (TTL: 2 minutes)
    const cacheKey = `eta:${engagementId}`;
    const cached = await this.cache.get(cacheKey);
    if (cached) return JSON.parse(cached);
    
    // Call Google Maps Directions API
    const response = await this.directionsAPI.getDirections({
      origin: `${fromLocation.lat},${fromLocation.lng}`,
      destination: `${toLocation.lat},${toLocation.lng}`,
      mode: 'driving',
      departure_time: 'now', // For traffic-aware ETA
      traffic_model: 'best_guess'
    });
    
    if (!response.routes || response.routes.length === 0) {
      throw new Error('No route found');
    }
    
    const route = response.routes[0];
    const leg = route.legs[0];
    
    // Calculate ETA range (±20%)
    const durationSeconds = leg.duration_in_traffic?.value || leg.duration.value;
    const minSeconds = Math.floor(durationSeconds * 0.8);
    const maxSeconds = Math.ceil(durationSeconds * 1.2);
    
    const result: ETAResult = {
      engagement_id: engagementId,
      distance_meters: leg.distance.value,
      duration_seconds: durationSeconds,
      eta_range: { min_seconds: minSeconds, max_seconds: maxSeconds },
      traffic_aware: !!leg.duration_in_traffic,
      calculated_at: Date.now(),
      confidence: this.calculateConfidence(leg),
      route_polyline: route.overview_polyline?.points
    };
    
    // Cache for 2 minutes
    await this.cache.set(cacheKey, JSON.stringify(result), 'EX', 120);
    
    return result;
  }
  
  private calculateConfidence(leg: any): 'high' | 'medium' | 'low' {
    if (leg.duration_in_traffic && leg.distance.value < 10000) {
      return 'high'; // Traffic data + short distance
    } else if (leg.duration_in_traffic) {
      return 'medium'; // Traffic data but longer distance
    } else {
      return 'low'; // No traffic data
    }
  }
}
```

### 6.2 Client-Side ETA Updates

```typescript
// Update ETA locally without API calls for smooth updates
function updateETALocally(
  currentETA: ETAResult,
  elapsedSeconds: number
): ETAResult {
  const remainingSeconds = Math.max(0, currentETA.duration_seconds - elapsedSeconds);
  
  return {
    ...currentETA,
    duration_seconds: remainingSeconds,
    eta_range: {
      min_seconds: Math.max(0, currentETA.eta_range.min_seconds - elapsedSeconds),
      max_seconds: Math.max(0, currentETA.eta_range.max_seconds - elapsedSeconds)
    }
  };
}
```

---

## 7. Team Tracking Implementation

```typescript
interface TeamTrackingLogic {
  // Determine if engagement has team
  isTeamEngagement(engagementId: number): Promise<boolean>;
  
  // Get team details
  getTeamDetails(engagementId: number): Promise<{
    lead_provider_id: number;
    member_ids: number[];
    member_names: string[];
  }>;
  
  // Track only lead provider
  getLeadProviderLocation(engagementId: number): Promise<LocationUpdate>;
}

// In tracking service, filter location updates
async function processLocationUpdate(update: LocationUpdate) {
  const engagement = await getEngagement(update.engagement_id);
  
  if (engagement.is_team) {
    // Only broadcast lead provider's location
    if (update.provider_id === engagement.lead_provider_id) {
      await broadcastLocationUpdate(update);
    }
  } else {
    await broadcastLocationUpdate(update);
  }
}
```

---

## 8. Messaging Integration

### 8.1 Message Button Component

```typescript
function MessageButton({ engagementId, providerId }) {
  const [quickMessageOpen, setQuickMessageOpen] = useState(false);
  const { sendMessage } = useMessaging();
  
  const quickTemplates = [
    "Where should I park?",
    "What's the gate/entry code?",
    "Running a few minutes late",
    "I'm here!"
  ];
  
  const handleQuickMessage = async (template: string) => {
    await sendMessage({
      engagement_id: engagementId,
      to_provider_id: providerId,
      message: template
    });
    setQuickMessageOpen(false);
  };
  
  return (
    <>
      <Button onClick={() => setQuickMessageOpen(true)}>
        <MessageIcon />
        Message
      </Button>
      
      <QuickMessageModal
        open={quickMessageOpen}
        onClose={() => setQuickMessageOpen(false)}
        templates={quickTemplates}
        onSend={handleQuickMessage}
      />
    </>
  );
}
```

### 8.2 Message API Integration

```typescript
// POST /api/messaging/send
interface SendMessageRequest {
  engagement_id: number;
  to_provider_id: number;
  message: string;
  context: 'tracking'; // Indicates message sent from tracking view
}

// Integrate with existing chat system
async function sendTrackingMessage(request: SendMessageRequest) {
  // Store message in existing chat system
  const messageId = await chatService.createMessage({
    engagement_id: request.engagement_id,
    sender_id: getCurrentCustomerId(),
    sender_type: 'customer',
    recipient_id: request.to_provider_id,
    recipient_type: 'provider',
    content: request.message,
    sent_from: 'tracking_view'
  });
  
  // Send push notification to provider
  await notificationService.sendPush({
    user_id: request.to_provider_id,
    title: 'Message from Customer',
    body: request.message,
    data: { engagement_id: request.engagement_id, type: 'chat' }
  });
  
  return { message_id: messageId, sent_at: Date.now() };
}
```

---

## 9. Security & Privacy

### 9.1 Authentication & Authorization

```typescript
// Middleware to verify tracking session
async function verifyTrackingSession(req, res, next) {
  const sessionToken = req.headers.authorization?.replace('Bearer ', '');
  
  if (!sessionToken) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  const session = await redis.get(`tracking_session:${sessionToken}`);
  if (!session) {
    return res.status(401).json({ error: 'Invalid session' });
  }
  
  const sessionData = JSON.parse(session);
  
  // Verify customer owns this engagement
  const engagement = await db.query(
    'SELECT customer_id FROM engagements WHERE id = $1',
    [sessionData.engagement_id]
  );
  
  if (engagement.rows[0].customer_id !== sessionData.customer_id) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  
  req.trackingSession = sessionData;
  next();
}
```

### 9.2 Data Purging

```typescript
// Auto-purge location data when service completes
async function onServiceCompleted(engagementId: number) {
  // Delete all location history
  await redis.del(`location_history:${engagementId}`);
  
  // Delete tracking session
  await redis.del(`tracking_session:${engagementId}`);
  
  // Mark engagement tracking as inactive
  await db.query(
    'UPDATE engagements SET tracking_active = false WHERE id = $1',
    [engagementId]
  );
  
  // Broadcast status change to all connected clients
  await pubsub.publish(`tracking:${engagementId}`, {
    type: 'status_change',
    engagement_id: engagementId,
    new_status: 'completed'
  });
}
```

### 9.3 Rate Limiting

```typescript
// Rate limit location updates from providers
const locationUpdateLimiter = rateLimit({
  windowMs: 15 * 1000, // 15 seconds
  max: 1, // Max 1 update per 15 seconds
  keyGenerator: (req) => `provider:${req.body.provider_id}`,
  message: 'Too many location updates, please slow down'
});

// Rate limit tracking session creation
const sessionLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 5, // Max 5 sessions per minute
  keyGenerator: (req) => `customer:${req.body.customer_id}`,
  message: 'Too many tracking session requests'
});
```

---

## 10. Performance Optimization

### 10.1 Location Update Batching

```typescript
// Batch multiple location updates for same engagement
class LocationUpdateBatcher {
  private buffer: Map<number, LocationUpdate[]> = new Map();
  private flushInterval = 2000; // 2 seconds
  
  constructor() {
    setInterval(() => this.flush(), this.flushInterval);
  }
  
  add(update: LocationUpdate) {
    if (!this.buffer.has(update.engagement_id)) {
      this.buffer.set(update.engagement_id, []);
    }
    this.buffer.get(update.engagement_id)!.push(update);
  }
  
  private async flush() {
    for (const [engagementId, updates] of this.buffer.entries()) {
      if (updates.length > 0) {
        // Send only the latest update
        const latest = updates[updates.length - 1];
        await this.broadcastUpdate(latest);
      }
    }
    this.buffer.clear();
  }
}
```

### 10.2 Map Rendering Optimization

```typescript
// Throttle map updates to avoid excessive re-renders
const useThrottledLocationUpdate = (location: LocationUpdate, delay = 1000) => {
  const [throttledLocation, setThrottledLocation] = useState(location);
  
  useEffect(() => {
    const timer = setTimeout(() => {
      setThrottledLocation(location);
    }, delay);
    
    return () => clearTimeout(timer);
  }, [location, delay]);
  
  return throttledLocation;
};

// Smooth marker animation
function animateMarker(
  marker: google.maps.Marker,
  newPosition: google.maps.LatLng,
  duration = 1000
) {
  const startPosition = marker.getPosition()!;
  const startTime = Date.now();
  
  function frame() {
    const elapsed = Date.now() - startTime;
    const progress = Math.min(elapsed / duration, 1);
    
    // Easing function
    const eased = 1 - Math.pow(1 - progress, 3);
    
    const lat = startPosition.lat() + (newPosition.lat() - startPosition.lat()) * eased;
    const lng = startPosition.lng() + (newPosition.lng() - startPosition.lng()) * eased;
    
    marker.setPosition(new google.maps.LatLng(lat, lng));
    
    if (progress < 1) {
      requestAnimationFrame(frame);
    }
  }
  
  requestAnimationFrame(frame);
}
```

### 10.3 Redis Caching Strategy

```typescript
// Cache structure in Redis
// 1. Active sessions: `tracking_session:<session_id>` (TTL: 24 hours)
// 2. Location updates: `location_history:<engagement_id>` (List, keep last 10)
// 3. ETA cache: `eta:<engagement_id>` (TTL: 2 minutes)
// 4. Provider status: `provider_status:<engagement_id>` (TTL: 1 hour)

// Store location with limited history
async function storeLocationUpdate(update: LocationUpdate) {
  const key = `location_history:${update.engagement_id}`;
  
  // Add to list
  await redis.lpush(key, JSON.stringify(update));
  
  // Keep only last 10 updates
  await redis.ltrim(key, 0, 9);
  
  // Set expiry to 1 hour
  await redis.expire(key, 3600);
}
```

---

## 11. Error Handling

### 11.1 Client-Side Error Scenarios

```typescript
enum TrackingError {
  SESSION_EXPIRED = 'Session has expired, please refresh',
  TRACKING_UNAVAILABLE = 'Tracking is currently unavailable',
  CONNECTION_FAILED = 'Failed to connect to tracking service',
  LOCATION_UNAVAILABLE = 'Provider location is unavailable',
  MAP_LOAD_FAILED = 'Failed to load map',
  PERMISSION_DENIED = 'Location permission denied',
  NETWORK_ERROR = 'Network connection issue'
}

function handleTrackingError(error: TrackingError) {
  switch (error) {
    case TrackingError.SESSION_EXPIRED:
      // Refresh session
      return restartTrackingSession();
    
    case TrackingError.CONNECTION_FAILED:
      // Fall back to polling
      return switchToPolling();
    
    case TrackingError.TRACKING_UNAVAILABLE:
      // Show unavailable message
      return showUnavailableMessage();
    
    case TrackingError.MAP_LOAD_FAILED:
      // Retry map initialization
      return retryMapLoad();
    
    default:
      // Show generic error
      return showGenericError(error);
  }
}
```

### 11.2 Backend Error Handling

```typescript
// Graceful degradation when external services fail
async function calculateETAWithFallback(from: Location, to: Location) {
  try {
    // Try Google Maps Directions API
    return await googleMapsETA(from, to);
  } catch (error) {
    console.error('Google Maps API failed:', error);
    
    try {
      // Fallback to simple distance calculation
      return calculateStraightLineETA(from, to);
    } catch (fallbackError) {
      console.error('Fallback ETA calculation failed:', fallbackError);
      // Return null, client will show "Calculating..."
      return null;
    }
  }
}

function calculateStraightLineETA(from: Location, to: Location): ETAResult {
  const distance = haversineDistance(from, to);
  const avgSpeed = 30 * 1000 / 3600; // 30 km/h in m/s
  const durationSeconds = Math.ceil(distance / avgSpeed);
  
  return {
    engagement_id: 0,
    distance_meters: distance,
    duration_seconds: durationSeconds,
    eta_range: {
      min_seconds: Math.floor(durationSeconds * 0.8),
      max_seconds: Math.ceil(durationSeconds * 1.2)
    },
    traffic_aware: false,
    calculated_at: Date.now(),
    confidence: 'low'
  };
}
```

---

## 12. Testing Strategy

### 12.1 Unit Tests
- Location update processing
- Position estimation algorithm
- ETA calculation logic
- WebSocket message handling
- Team tracking logic

### 12.2 Integration Tests
- REST API endpoints
- WebSocket connection lifecycle
- Redis pub/sub messaging
- Database queries
- External API integration (Google Maps)

### 12.3 End-to-End Tests
- Complete tracking session flow
- Offline mode behavior
- ETA updates and display
- Messaging integration
- Error handling scenarios

### 12.4 Performance Tests
- WebSocket connection scalability (1000+ concurrent)
- Location update throughput
- Map rendering performance
- Memory usage monitoring
- Battery impact testing (mobile)

---

## 13. Deployment Considerations

### 13.1 Infrastructure Requirements
- WebSocket server cluster (min 2 instances for HA)
- Redis cluster for pub/sub (min 3 nodes)
- Load balancer with WebSocket support
- CDN for map tile caching
- Monitoring and alerting (Datadog, New Relic)

### 13.2 Environment Variables
```
# Map Provider
GOOGLE_MAPS_API_KEY=<api_key>
MAP_PROVIDER=google_maps

# WebSocket
WS_PORT=8080
WS_PATH=/tracking/ws
WS_HEARTBEAT_INTERVAL=30000

# Redis
REDIS_URL=redis://localhost:6379
REDIS_PUB_SUB_CHANNEL=tracking_updates

# Rate Limiting
LOCATION_UPDATE_RATE_LIMIT=1 # per 15 seconds
SESSION_CREATE_RATE_LIMIT=5 # per minute

# Features
ENABLE_OFFLINE_ESTIMATION=true
ENABLE_TEAM_TRACKING=true
MAX_ESTIMATION_TIME_SECONDS=600
```

### 13.3 Monitoring Metrics
- Active tracking sessions count
- WebSocket connection count
- Location update rate (per second)
- ETA calculation latency
- Map API usage and costs
- Error rates by type
- Average session duration

---

## 14. Future Enhancements

1. **Route Polyline Display** - Show expected route on map
2. **Geofencing Alerts** - Notify when provider enters vicinity
3. **Traffic Layer** - Show traffic conditions on map
4. **Multi-Provider Tracking** - Track all team members individually
5. **Historical Route Playback** - Review past routes (if privacy allows)
6. **Provider Navigation Integration** - Share routes with provider apps
7. **Predictive ETA** - ML-based ETA using historical data
8. **Customer Location Sharing** - Help provider find exact location

---

## 15. Cross-Platform Code Sharing

### 15.1 Shared Business Logic

Create a shared TypeScript package for common logic:

```
@servease/tracking-shared/
├── src/
│   ├── types/
│   │   ├── LocationUpdate.ts
│   │   ├── TrackingSession.ts
│   │   └── ETAResult.ts
│   ├── utils/
│   │   ├── coordinateCalculations.ts
│   │   ├── positionEstimator.ts
│   │   └── etaFormatter.ts
│   ├── validators/
│   │   └── locationValidator.ts
│   └── constants/
│       └── trackingConstants.ts
└── package.json
```

Import in both web and iOS:
```typescript
import { estimatePosition, formatETA } from '@servease/tracking-shared';
```

### 15.2 Platform-Specific Implementations

**Web (Google Maps):**
```typescript
import { Loader } from '@googlemaps/js-api-loader';

const loader = new Loader({
  apiKey: process.env.GOOGLE_MAPS_API_KEY!,
  version: 'weekly'
});

const google = await loader.load();
const map = new google.maps.Map(mapRef.current, options);
```

**iOS (React Native Maps):**
```typescript
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps';

<MapView
  provider={PROVIDER_GOOGLE}
  style={styles.map}
  initialRegion={region}
>
  <Marker coordinate={providerLocation} />
</MapView>
```

---

This technical design provides a complete blueprint for implementing the Service Provider Live Tracking feature across web and iOS platforms with real-time updates, ETA calculation, offline support, team tracking, and messaging integration.
