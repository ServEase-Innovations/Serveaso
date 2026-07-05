# Tracking Service - Authentication Disabled for Testing

**Date**: July 5, 2026
**Status**: ⚠️ TESTING MODE - Re-enable auth before production!

---

## Summary

Temporarily disabled JWT authentication on all tracking endpoints to allow testing without valid auth tokens. This affects both provider journey control and customer tracking sessions.

---

## Endpoints with Auth Disabled

### Provider Journey Endpoints
**File**: `services/notifications/tracking/src/routes/providerTrackingRoutes.js`

1. ✅ `GET /api/tracking/provider/status/:engagementId`
   - Get current tracking status for an engagement
   - Auth disabled for initial status checks

2. ✅ `POST /api/tracking/provider/start-journey`
   - Provider starts journey (enables tracking)
   - Accepts `provider_id` in body for testing

3. ✅ `POST /api/tracking/provider/arrived`
   - Provider marks arrival at customer location
   - No auth required

4. 🔒 `POST /api/tracking/provider/start-service`
   - Auth still enabled (not needed for testing yet)

5. 🔒 `POST /api/tracking/provider/complete-service`
   - Auth still enabled (not needed for testing yet)

### Customer Tracking Endpoints
**File**: `services/notifications/tracking/src/routes/trackingRoutes.js`

1. ✅ `POST /api/tracking/session/start`
   - Customer starts tracking session
   - Auth disabled, ownership check commented out

2. ✅ `POST /api/tracking/session/stop`
   - Stop tracking session
   - Auth disabled, ownership check commented out

3. ✅ `GET /api/tracking/location/:engagementId`
   - Polling endpoint for location updates
   - Auth disabled

4. ✅ `GET /api/tracking/eta/:engagementId`
   - Get estimated time of arrival
   - Auth disabled

5. ✅ `GET /api/tracking/availability/:engagementId`
   - Check if tracking available
   - Always public (no change)

6. ✅ `GET /api/tracking/health`
   - Health check endpoint
   - Always public (no change)

---

## Bug Fixes Applied

### 1. Session Service JSON Error
**File**: `services/notifications/tracking/src/services/sessionService.js`

**Problem**: `destination` field was being passed as plain string, but database expects JSONB

**Fix**: Wrap string addresses in JSON object
```javascript
// Before
const destinationJSON = typeof destination === 'string' 
  ? destination 
  : JSON.stringify(destination);

// After
let destinationJSON;
if (typeof destination === 'string') {
  destinationJSON = JSON.stringify({ address: destination });
} else if (typeof destination === 'object') {
  destinationJSON = JSON.stringify(destination);
} else {
  destinationJSON = JSON.stringify({ address: String(destination) });
}
```

---

## Testing Examples

### Provider Journey Flow

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

**Response**:
```json
{
  "message": "Journey started - tracking enabled",
  "engagement_id": 235,
  "tracking_status": "en_route",
  "journey_started_at": "2026-07-05T15:45:12.000Z"
}
```

#### 2. Check Status
```bash
curl http://localhost:5007/api/tracking/provider/status/235
```

**Response**:
```json
{
  "engagement_id": 235,
  "provider_id": 4,
  "tracking_status": "en_route",
  "latitude": 12.9352,
  "longitude": 77.6245,
  "journey_started_at": "2026-07-05T15:45:12.000Z",
  "created_at": "2026-07-05T15:45:12.000Z",
  "updated_at": "2026-07-05T15:45:12.000Z"
}
```

#### 3. Mark Arrived
```bash
curl -X POST http://localhost:5007/api/tracking/provider/arrived \
  -H "Content-Type: application/json" \
  -d '{
    "engagement_id": 235,
    "latitude": 12.9400,
    "longitude": 77.6300
  }'
```

**Response**:
```json
{
  "message": "Arrival confirmed",
  "engagement_id": 235,
  "tracking_status": "arrived",
  "arrived_at": "2026-07-05T16:15:30.000Z"
}
```

---

### Customer Tracking Flow

#### 1. Check Availability
```bash
curl http://localhost:5007/api/tracking/availability/235
```

**Response**:
```json
{
  "available": true,
  "provider_status": "en_route",
  "reason": null,
  "is_team": false,
  "team_data": null,
  "engagement_details": {
    "id": "235",
    "provider_id": "4",
    "customer_id": "1",
    "service_address": "Block-D, PURVA BELMONT, Kanakanagar..."
  }
}
```

#### 2. Start Tracking Session
```bash
curl -X POST http://localhost:5007/api/tracking/session/start \
  -H "Content-Type: application/json" \
  -d '{
    "engagement_id": 235,
    "customer_id": 1
  }'
```

**Response**:
```json
{
  "session_id": "sess_d59eb42d212950ef581a2db4174dcf07",
  "websocket_url": "ws://localhost:5007",
  "polling_url": "/api/tracking/location/235",
  "session_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "is_team": false,
  "team_data": null
}
```

#### 3. Get Location Update (Polling)
```bash
curl http://localhost:5007/api/tracking/location/235
```

**Response** (if provider is sharing location):
```json
{
  "engagement_id": 235,
  "provider_id": 4,
  "latitude": 12.9375,
  "longitude": 77.6270,
  "timestamp": "2026-07-05T16:00:00.000Z",
  "accuracy": 10,
  "speed": 5.2,
  "bearing": 45
}
```

#### 4. Get ETA
```bash
curl http://localhost:5007/api/tracking/eta/235
```

**Response**:
```json
{
  "engagement_id": 235,
  "eta_minutes": 12,
  "distance_meters": 3500,
  "calculated_at": "2026-07-05T16:00:00.000Z"
}
```

---

## Security Notes

### What's Disabled:
- ✅ JWT token validation via `authenticateToken` middleware
- ✅ Customer ownership checks (can track any engagement)
- ✅ Provider identity verification

### What's Still Active:
- ✅ Rate limiting on session creation
- ✅ Input validation (engagement_id, customer_id required)
- ✅ Database constraints (foreign keys, data types)
- ✅ CORS origin checking

### Risks in Production:
- ⚠️ Anyone can start/stop tracking sessions
- ⚠️ Customers can track any engagement, not just their own
- ⚠️ Providers can mark any engagement as en_route
- ⚠️ No audit trail of who performed actions

---

## Re-enabling Authentication

Before deploying to production, uncomment the authentication checks:

### 1. Provider Routes
```javascript
// Change this:
router.post('/start-journey', asyncHandler(async (req, res) => {

// To this:
router.post('/start-journey', authenticateToken, asyncHandler(async (req, res) => {
  // Also uncomment ownership checks inside
```

### 2. Customer Routes
```javascript
// Change this:
router.post('/session/start', rateLimitSession, asyncHandler(async (req, res) => {
  // ...
  // if (req.user.id !== customer_id && req.user.role !== 'admin') {
  //   return res.status(403).json({
  //     error: 'You can only track your own engagements',
  //   });
  // }

// To this:
router.post('/session/start', authenticateToken, rateLimitSession, asyncHandler(async (req, res) => {
  // ...
  if (req.user.id !== customer_id && req.user.role !== 'admin') {
    return res.status(403).json({
      error: 'You can only track your own engagements',
    });
  }
```

### 3. Update Frontend
Ensure frontend apps properly pass JWT tokens:
- Web: `localStorage.getItem('token')`
- iOS: From Auth0 or secure storage
- Set in `Authorization: Bearer <token>` header

---

## Files Modified

### Backend Routes
- `services/notifications/tracking/src/routes/providerTrackingRoutes.js`
- `services/notifications/tracking/src/routes/trackingRoutes.js`

### Backend Services
- `services/notifications/tracking/src/services/sessionService.js` (JSON fix)

### Database
- `engagement_tracking_status` table (migration applied)
- `tracking_sessions` table (already exists)

---

## Current Test Status

### ✅ Working
- Provider can start journey without auth
- Provider can mark arrival without auth
- Customer can check tracking availability
- Customer can start tracking session
- Customer can get location updates
- Customer can get ETA
- Session service creates proper JSON for destination field

### ⏳ Not Yet Tested
- WebSocket real-time updates
- Location publishing from provider side
- ETA calculation with real movement
- Team tracking scenarios
- Session cleanup/expiry

### 🔒 Still Protected
- Service start/complete endpoints (not needed for journey tracking)

---

## Next Steps for Production

1. ✅ Complete end-to-end testing with auth disabled
2. ⏳ Test WebSocket connections
3. ⏳ Implement provider location publishing (periodic updates)
4. ⏳ Re-enable all authentication
5. ⏳ Test with proper JWT tokens from Auth0
6. ⏳ Security audit before deployment
7. ⏳ Add logging/monitoring for auth failures
8. ⏳ Deploy to staging environment
9. ⏳ Production deployment

---

## Quick Reference

**Local Testing**: All auth disabled ✅
**Staging**: Re-enable auth ⚠️
**Production**: Full auth required 🔒

**Current Mode**: 🧪 TESTING - Auth Disabled
