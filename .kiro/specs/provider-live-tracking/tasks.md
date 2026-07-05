# Implementation Plan: Service Provider Live Tracking

## Overview

This implementation plan breaks down the Service Provider Live Tracking feature into discrete, actionable tasks across backend infrastructure, frontend web (React), and frontend iOS (React Native). The feature enables customers to track their service provider's real-time location on a map with ETA calculations, messaging integration, and offline resilience.

**Technology Stack:**
- Backend: Node.js, TypeScript, Express, WebSocket (Socket.io), Redis Pub/Sub
- Web: React 18+, TypeScript, Google Maps JavaScript API
- iOS: React Native, TypeScript, React Native Maps, Socket.io-client
- Database: PostgreSQL, Redis

**Key Features:**
- Real-time location streaming via WebSocket
- ETA calculation with traffic awareness
- Position estimation for offline providers
- Team tracking (lead provider)
- In-app messaging from tracking view
- Cross-platform (Web + iOS)

---

## Tasks

### 1. Backend Infrastructure Setup

- [ ] 1.1 Create tracking service directory structure
  - Create `services/tracking/` directory with standard Node.js/TypeScript project structure
  - Initialize package.json with dependencies: express, socket.io, redis, ioredis, pg, @types packages
  - Configure TypeScript (tsconfig.json) with strict mode
  - Set up environment variables (.env.example) for Redis, PostgreSQL, Maps API keys
  - _Requirements: Technical infrastructure foundation_

- [ ] 1.2 Set up Redis Pub/Sub client
  - Create `src/redis/pubsubClient.ts` with ioredis publisher and subscriber clients
  - Implement connection management with retry logic
  - Add channel naming conventions (e.g., `tracking:location:${engagementId}`)
  - Export pub/sub functions: `publishLocationUpdate()`, `subscribeToEngagement()`
  - _Requirements: FR-3 (Real-Time Updates), NFR-2 (Scalability)_

- [ ] 1.3 Create database schema for tracking sessions
  - Design `tracking_sessions` table with fields: session_id, engagement_id, customer_id, provider_id, status, started_at, last_update_at, destination (JSONB)
  - Add indexes on engagement_id and customer_id for fast lookups
  - Create migration script in `database/migrations/`
  - Add `is_team` and `team_data` JSONB fields for team tracking
  - _Requirements: FR-4 (Tracking Lifecycle), US-11 (Track Team Services)_

- [ ] 1.4 Implement tracking availability check logic
  - Create `src/services/trackingAvailabilityService.ts`
  - Implement `checkAvailability(engagementId)` function that queries engagement status
  - Return availability based on provider state (not_started, en_route, arrived, in_progress, completed)
  - Include reason messages for unavailable states
  - _Requirements: US-3 (Tracking Availability), FR-4 (Tracking Lifecycle)_

- [ ] 1.5 Create REST API endpoints for tracking
  - Create `src/routes/trackingRoutes.ts` with Express router
  - Implement GET `/api/tracking/availability/:engagementId` endpoint
  - Implement POST `/api/tracking/session/start` endpoint (creates session, returns WebSocket URL and token)
  - Implement POST `/api/tracking/session/stop` endpoint
  - Implement GET `/api/tracking/eta/:engagementId` endpoint
  - Implement GET `/api/tracking/location/:engagementId` polling fallback endpoint
  - Add authentication middleware to verify customer access
  - _Requirements: FR-1 (Tracking Button Display), US-1 (View Provider Location), FR-9 (In-App Messaging Integration)_

### 2. WebSocket Server Implementation

- [ ] 2.1 Set up Socket.io WebSocket server
  - Create `src/websocket/trackingServer.ts` with Socket.io server setup
  - Configure CORS for web and mobile clients
  - Implement connection handler with token authentication
  - Add heartbeat/ping-pong mechanism (30-second interval)
  - _Requirements: FR-3 (Real-Time Updates), NFR-2 (Scalability)_

- [ ] 2.2 Implement WebSocket message handlers
  - Handle `subscribe` message: validate engagement access, join Redis channel
  - Handle `unsubscribe` message: leave Redis channel
  - Handle `ping` message: respond with `pong`
  - Store active connections in Redis with TTL
  - _Requirements: FR-3 (Real-Time Updates), US-2 (Real-Time Location Updates)_

- [ ] 2.3 Create location update broadcast logic
  - Create `src/services/locationBroadcastService.ts`
  - Subscribe to Redis pub/sub channels for location updates
  - Broadcast location updates to connected clients via Socket.io
  - Implement update batching (2-second buffer) to reduce broadcast frequency
  - _Requirements: FR-3 (Real-Time Updates), US-2 (Real-Time Location Updates), NFR-1 (Performance)_

- [ ] 2.4 Implement connection lifecycle management
  - Handle client disconnect: clean up Redis subscriptions, remove from active sessions
  - Implement exponential backoff reconnection strategy
  - Broadcast `connection_lost` event when provider goes offline (60s timeout)
  - Track connection status in Redis
  - _Requirements: FR-3 (Real-Time Updates), US-7 (Network Resilience), FR-11 (Offline Mode)_

### 3. Location Processing & ETA Calculation

- [ ] 3.1 Create location update processor
  - Create `src/services/locationProcessor.ts`
  - Validate location update payload (latitude, longitude, accuracy, bearing, speed, timestamp)
  - Store location update in Redis list (keep last 10 updates, TTL 1 hour)
  - Publish location update to Redis pub/sub channel
  - Update `last_update_at` timestamp in tracking_sessions table
  - _Requirements: FR-5 (Location Data), US-2 (Real-Time Location Updates)_

- [ ] 3.2 Implement Google Maps Directions API integration
  - Create `src/external/googleMapsClient.ts`
  - Implement `getDirections(origin, destination, mode, trafficModel)` function
  - Parse response to extract distance, duration, duration_in_traffic, polyline
  - Add error handling and retry logic for API failures
  - Implement rate limiting to stay within API quotas
  - _Requirements: FR-8 (ETA Calculation and Display), US-9 (View ETA)_

- [ ] 3.3 Create ETA calculation service
  - Create `src/services/etaCalculator.ts`
  - Implement `calculateETA(fromLocation, toLocation, engagementId)` using Directions API
  - Calculate ETA range (±20%) for uncertainty
  - Determine confidence level (high/medium/low) based on traffic data and distance
  - Cache ETA results in Redis (2-minute TTL)
  - Fallback to straight-line distance calculation if API fails
  - _Requirements: FR-8 (ETA Calculation and Display), US-9 (View ETA), NFR-3 (Reliability)_

- [ ] 3.4 Implement position estimation algorithm
  - Create `src/services/positionEstimator.ts`
  - Implement haversine formula for position projection based on last known location, speed, bearing, and elapsed time
  - Calculate confidence score (decreases over time, max 10 minutes)
  - Return `EstimatedPosition` object with estimation metadata
  - Stop projecting after 10 minutes, return last known location
  - _Requirements: FR-11 (Offline Mode with Position Estimation), US-7 (Network Resilience)_

- [ ] 3.5 Create team tracking logic
  - Create `src/services/teamTrackingService.ts`
  - Implement `getTeamDetails(engagementId)` to query team assignments
  - Filter location updates to only broadcast lead provider's position
  - Add team metadata to tracking session (lead_provider_id, member_ids, member_count)
  - _Requirements: FR-10 (Team Service Tracking), US-11 (Track Team Services)_

### 4. Security & Privacy Implementation

- [ ] 4.1 Implement authentication and authorization middleware
  - Create `src/middleware/trackingAuth.ts`
  - Verify JWT token or session token for REST API and WebSocket connections
  - Validate customer can only track their assigned engagements
  - Add rate limiting middleware (5 requests/minute for session creation)
  - _Requirements: NFR-4 (Security), US-5 (Provider Privacy)_

- [ ] 4.2 Implement data purging logic
  - Create `src/services/dataPurgeService.ts`
  - Implement `onServiceCompleted(engagementId)` to delete location history, tracking sessions
  - Schedule background job to auto-purge completed sessions (every 5 minutes)
  - Add logging for audit trail
  - _Requirements: US-5 (Provider Privacy), NFR-5 (Privacy)_

- [ ] 4.3 Add encryption for sensitive data
  - Ensure all location data transmitted over HTTPS/WSS
  - Encrypt location updates at rest in Redis (if required by compliance)
  - Configure SSL/TLS certificates for WebSocket server
  - _Requirements: NFR-4 (Security), NFR-5 (Privacy)_

### 5. Web Frontend - React Components

- [ ] 5.1 Create tracking feature directory structure
  - Create `apps/servase-ui/src/features/tracking/` directory
  - Set up subdirectories: components/, hooks/, services/, store/, utils/
  - Initialize tracking Redux slice in store/
  - _Requirements: Technical infrastructure foundation_

- [ ] 5.2 Implement TrackButton component
  - Create `components/TrackButton.tsx` in Today's Services booking card
  - Show button states: enabled (en_route), disabled (not_started, arrived), loading
  - Call availability API on mount to determine state
  - Display tooltip/message for disabled state
  - Open tracking map view on click
  - _Requirements: FR-1 (Tracking Button Display), US-1 (View Provider Location)_

- [ ] 5.3 Create TrackingMapView component
  - Create `components/TrackingMapView.tsx` full-screen modal/drawer
  - Initialize Google Maps JavaScript API
  - Set up map container with close button, zoom controls, recenter button
  - Handle map load errors gracefully
  - _Requirements: FR-2 (Map View), US-1 (View Provider Location), NFR-6 (Accessibility)_

- [ ] 5.4 Implement ProviderMarker component
  - Create `components/ProviderMarker.tsx`
  - Render provider location marker with avatar/icon on Google Maps
  - Show accuracy radius circle
  - Add pulsing animation for real-time feel
  - Handle estimated position state (semi-transparent marker)
  - _Requirements: FR-2 (Map View), US-2 (Real-Time Location Updates), FR-11 (Offline Mode)_

- [ ] 5.5 Implement DestinationMarker component
  - Create `components/DestinationMarker.tsx`
  - Render service address marker on Google Maps
  - Display address label on hover
  - _Requirements: FR-2 (Map View), US-1 (View Provider Location)_

- [ ] 5.6 Create ETADisplay component
  - Create `components/ETADisplay.tsx` card/banner at top of map view
  - Display ETA range (e.g., "Arriving in 15-20 min") with color-coded indicator
  - Show distance if ETA unavailable
  - Display "Calculating..." loading state
  - Update every second with client-side countdown
  - _Requirements: FR-8 (ETA Calculation and Display), US-9 (View ETA)_

- [ ] 5.7 Implement OfflineBanner component
  - Create `components/OfflineBanner.tsx`
  - Show banner when connection lost or provider offline
  - Display "Last updated X minutes ago" timestamp
  - Show "Reconnecting..." indicator
  - Add retry button
  - _Requirements: FR-11 (Offline Mode), US-7 (Network Resilience), US-4 (Error Handling)_

- [ ] 5.8 Create MessageButton component
  - Create `components/MessageButton.tsx` floating action button
  - Open quick message modal with templates: "Where to park?", "Gate code?", "Running late", "I'm here!"
  - Allow custom message input
  - Integrate with existing chat/messaging API
  - Show unread message badge
  - _Requirements: FR-9 (In-App Messaging Integration), US-10 (Message Provider During Transit)_

### 6. Web Frontend - State Management & Services

- [ ] 6.1 Create tracking Redux slice
  - Create `store/trackingSlice.ts` with Redux Toolkit
  - Define `TrackingState` interface (session, connection, provider, destination, eta, team, map, ui)
  - Implement actions: startSession, stopSession, updateLocation, updateETA, setConnectionStatus, setError
  - Add selectors for computed values
  - _Requirements: Technical state management foundation_

- [ ] 6.2 Implement WebSocket client service
  - Create `services/websocketClient.ts` class for Socket.io-client
  - Implement connect(), disconnect(), subscribe(), send() methods
  - Handle connection lifecycle: onopen, onmessage, onerror, onclose
  - Implement exponential backoff reconnection (max 5 attempts)
  - Start heartbeat ping every 30 seconds
  - _Requirements: FR-3 (Real-Time Updates), US-2 (Real-Time Location Updates), US-7 (Network Resilience)_

- [ ] 6.3 Create tracking API service
  - Create `services/trackingAPI.ts` with axios
  - Implement API functions: checkAvailability(), startSession(), stopSession(), getETA(), getLocation() (polling)
  - Add error handling and retry logic
  - _Requirements: FR-1 (Tracking Button Display), US-1 (View Provider Location), US-9 (View ETA)_

- [ ] 6.4 Implement position estimator utility
  - Create `services/positionEstimator.ts`
  - Implement client-side position estimation using last location, speed, bearing, elapsed time
  - Calculate confidence score (0-1, decreases over time)
  - Return estimated position object
  - _Requirements: FR-11 (Offline Mode with Position Estimation), US-7 (Network Resilience)_

- [ ] 6.5 Create custom hooks for tracking functionality
  - Create `hooks/useTrackingSession.ts` to manage session lifecycle (start/stop)
  - Create `hooks/useLocationUpdates.ts` to handle WebSocket connection and location updates
  - Create `hooks/usePositionEstimation.ts` to calculate estimated position when offline
  - Create `hooks/useETACalculation.ts` for client-side ETA countdown
  - Create `hooks/useMapControls.ts` for map zoom, center, recenter logic
  - _Requirements: Technical hooks for component logic_

### 7. Web Frontend - Map Integration & Animations

- [ ] 7.1 Integrate Google Maps JavaScript API
  - Add Google Maps script to index.html with API key
  - Create `services/mapProvider.ts` wrapper for Google Maps API
  - Implement map initialization, marker creation, polyline drawing
  - Handle API load errors
  - _Requirements: FR-7 (Map Integration), NFR-1 (Performance)_

- [ ] 7.2 Implement smooth marker animations
  - Create `utils/markerAnimations.ts`
  - Implement `animateMarker()` function using requestAnimationFrame
  - Use easing function for smooth transitions (1-second duration)
  - Handle rapid location updates (throttle to 1 update per second)
  - _Requirements: US-2 (Real-Time Location Updates), NFR-1 (Performance)_

- [ ] 7.3 Implement map auto-centering logic
  - Calculate bounds to show both provider and destination markers
  - Implement smooth pan/zoom animations
  - Add "recenter" button to reset view
  - Disable auto-center when user manually pans map
  - _Requirements: FR-2 (Map View), US-1 (View Provider Location)_

### 8. iOS Frontend - React Native Components

- [ ] 8.1 Create tracking feature directory structure
  - Create `apps/servease-ios/src/features/tracking/` directory
  - Set up subdirectories: components/, hooks/, services/, store/, utils/
  - Initialize tracking Redux slice in store/ (reuse web logic)
  - _Requirements: Technical infrastructure foundation_

- [ ] 8.2 Implement TrackButton component (iOS)
  - Create `components/TrackButton.tsx` for Today's Services booking card
  - Use React Native TouchableOpacity/Pressable
  - Show button states: enabled, disabled, loading
  - Call availability API on mount
  - Navigate to tracking map screen on press
  - _Requirements: FR-1 (Tracking Button Display), US-1 (View Provider Location)_

- [ ] 8.3 Create TrackingMapView screen (iOS)
  - Create `components/TrackingMapView.tsx` full-screen screen
  - Initialize React Native Maps (MapView component)
  - Set up navigation header with close button
  - Add zoom controls overlay
  - Handle map load errors
  - _Requirements: FR-2 (Map View), US-1 (View Provider Location), US-6 (Cross-Platform Consistency)_

- [ ] 8.4 Implement ProviderMarker component (iOS)
  - Create `components/ProviderMarker.tsx` using React Native Maps Marker
  - Render custom marker with provider avatar
  - Show accuracy radius circle
  - Handle estimated position state (opacity change)
  - _Requirements: FR-2 (Map View), US-2 (Real-Time Location Updates), FR-11 (Offline Mode)_

- [ ] 8.5 Implement DestinationMarker component (iOS)
  - Create `components/DestinationMarker.tsx` using React Native Maps Marker
  - Render destination marker with custom icon
  - Display address in callout on press
  - _Requirements: FR-2 (Map View), US-1 (View Provider Location)_

- [ ] 8.6 Create ETADisplay component (iOS)
  - Create `components/ETADisplay.tsx` card overlay at top of map
  - Use React Native View, Text, styled with StyleSheet
  - Display ETA range with color-coded background
  - Show distance if ETA unavailable
  - Display loading indicator
  - Update every second with client-side countdown
  - _Requirements: FR-8 (ETA Calculation and Display), US-9 (View ETA)_

- [ ] 8.7 Implement OfflineBanner component (iOS)
  - Create `components/OfflineBanner.tsx`
  - Show banner when connection lost
  - Display timestamp of last update
  - Show reconnecting indicator
  - Add retry button
  - _Requirements: FR-11 (Offline Mode), US-7 (Network Resilience), US-4 (Error Handling)_

- [ ] 8.8 Create MessageButton component (iOS)
  - Create `components/MessageButton.tsx` floating action button
  - Open modal with quick message templates
  - Integrate with existing messaging API
  - Show unread message badge
  - _Requirements: FR-9 (In-App Messaging Integration), US-10 (Message Provider During Transit)_

### 9. iOS Frontend - Services & State Management

- [ ] 9.1 Implement WebSocket client service (iOS)
  - Create `services/websocketClient.ts` using socket.io-client
  - Implement connect(), disconnect(), subscribe(), send() methods
  - Handle connection lifecycle events
  - Implement exponential backoff reconnection
  - Start heartbeat ping every 30 seconds
  - Handle iOS background state (pause connection when app backgrounded)
  - _Requirements: FR-3 (Real-Time Updates), US-2 (Real-Time Location Updates), US-8 (Battery Optimization)_

- [ ] 9.2 Create tracking API service (iOS)
  - Create `services/trackingAPI.ts` with axios
  - Implement API functions: checkAvailability(), startSession(), stopSession(), getETA(), getLocation()
  - Add error handling and retry logic
  - _Requirements: FR-1 (Tracking Button Display), US-1 (View Provider Location)_

- [ ] 9.3 Implement position estimator utility (iOS)
  - Create `services/positionEstimator.ts` (reuse web logic)
  - Implement client-side position estimation
  - Calculate confidence score
  - _Requirements: FR-11 (Offline Mode with Position Estimation), US-7 (Network Resilience)_

- [ ] 9.4 Implement React Native Maps integration
  - Install and configure react-native-maps
  - Create `services/mapProvider.ts` wrapper for React Native Maps API
  - Implement animated marker movement using Animated API
  - Handle platform differences (iOS uses Apple Maps by default)
  - _Requirements: FR-7 (Map Integration), NFR-1 (Performance)_

- [ ] 9.5 Implement offline handling and caching
  - Use AsyncStorage to cache last known location
  - Restore cached location on app restart
  - Handle network state changes with NetInfo
  - Show offline indicator when network unavailable
  - _Requirements: US-7 (Network Resilience), FR-11 (Offline Mode)_

### 10. Cross-Platform Features & Integration

- [ ] 10.1 Implement messaging integration (Web & iOS)
  - Integrate MessageButton with existing chat/messaging system API
  - Implement quick message templates
  - Handle message sending and delivery confirmation
  - Show push notification status
  - _Requirements: FR-9 (In-App Messaging Integration), US-10 (Message Provider During Transit)_

- [ ] 10.2 Implement team tracking UI (Web & iOS)
  - Show "Team" label instead of provider name when is_team = true
  - Display team member list in expandable details panel
  - Show team size indicator on marker
  - Use same ETA for team
  - _Requirements: FR-10 (Team Service Tracking), US-11 (Track Team Services)_

- [ ] 10.3 Implement error handling and user feedback (Web & iOS)
  - Create error message components for common errors (session expired, tracking unavailable, connection failed)
  - Implement retry logic with exponential backoff
  - Add fallback to polling when WebSocket fails
  - Show user-friendly error messages
  - _Requirements: US-4 (Error Handling), NFR-3 (Reliability)_

- [ ] 10.4 Implement accessibility features (Web & iOS)
  - Add ARIA labels and roles for screen readers (Web)
  - Add accessibility labels for React Native components (iOS)
  - Ensure keyboard navigation works on web
  - Test with VoiceOver (iOS) and screen readers (Web)
  - Implement high contrast mode support
  - _Requirements: NFR-6 (Accessibility)_

### 11. Testing & Quality Assurance

- [ ]* 11.1 Write unit tests for backend services
  - Test location processor: validation, Redis storage, pub/sub publish
  - Test ETA calculator: Google Maps API integration, fallback logic, caching
  - Test position estimator: haversine calculation, confidence scoring
  - Test team tracking logic: lead provider filtering
  - Use Jest for unit testing
  - _Requirements: Ensure code quality and correctness_

- [ ]* 11.2 Write integration tests for REST API endpoints
  - Test GET /api/tracking/availability/:engagementId with various engagement states
  - Test POST /api/tracking/session/start with authentication
  - Test GET /api/tracking/eta/:engagementId with caching
  - Test polling endpoint GET /api/tracking/location/:engagementId
  - Use supertest for API testing
  - _Requirements: Ensure API contracts are correct_

- [ ]* 11.3 Write WebSocket integration tests
  - Test connection lifecycle (connect, subscribe, disconnect)
  - Test location update broadcasting
  - Test heartbeat/ping-pong mechanism
  - Test reconnection logic
  - Use socket.io-client for testing
  - _Requirements: Ensure WebSocket reliability_

- [ ]* 11.4 Write unit tests for frontend components (Web)
  - Test TrackButton: button states, availability check, click handler
  - Test ETADisplay: ETA formatting, countdown, loading state
  - Test OfflineBanner: visibility logic, retry button
  - Test WebSocket client: connection, reconnection, message handling
  - Use Jest + React Testing Library
  - _Requirements: Ensure UI components work correctly_

- [ ]* 11.5 Write unit tests for iOS components
  - Test TrackButton: button states, navigation
  - Test ETADisplay: ETA formatting, countdown
  - Test OfflineBanner: visibility, retry
  - Test WebSocket client: connection, background handling
  - Use Jest + React Native Testing Library
  - _Requirements: Ensure iOS UI components work correctly_

- [ ]* 11.6 Write end-to-end tests for tracking flow
  - Test complete tracking session: start session → WebSocket connection → location updates → ETA updates → stop session
  - Test offline mode: disconnect provider → show estimated position → reconnect → resume updates
  - Test messaging from tracking view
  - Test team tracking display
  - Use Playwright (Web) or Detox (iOS)
  - _Requirements: Ensure full user flow works end-to-end_

- [ ]* 11.7 Perform performance testing
  - Load test WebSocket server with 1000+ concurrent connections
  - Test location update throughput (updates per second)
  - Test map rendering performance (frame rate)
  - Test memory usage and leaks
  - Use Artillery for load testing, React DevTools Profiler for frontend
  - _Requirements: NFR-1 (Performance), NFR-2 (Scalability)_

### 12. Deployment & Monitoring

- [ ] 12.1 Set up tracking service deployment configuration
  - Create Dockerfile for tracking service
  - Configure environment variables for production (Redis, PostgreSQL, Maps API)
  - Set up AWS deployment scripts (ECS, Elastic Beanstalk, or EC2)
  - Configure load balancer for WebSocket scaling
  - _Requirements: NFR-2 (Scalability), NFR-3 (Reliability)_

- [ ] 12.2 Configure Redis cluster for production
  - Set up Redis Cluster or Redis Sentinel for high availability
  - Configure pub/sub channels
  - Set appropriate memory limits and eviction policies
  - Configure persistence (RDB snapshots)
  - _Requirements: NFR-2 (Scalability), NFR-3 (Reliability)_

- [ ] 12.3 Set up monitoring and alerting
  - Add application metrics (location updates/sec, active sessions, WebSocket connections)
  - Set up error tracking (Sentry or similar)
  - Configure log aggregation (CloudWatch, ELK stack)
  - Create alerts for high error rates, connection failures, API quota limits
  - Monitor Google Maps API usage and costs
  - _Requirements: NFR-3 (Reliability), Success Metrics_

- [ ] 12.4 Create deployment documentation
  - Document deployment process for tracking service
  - Document environment variable configuration
  - Document Redis setup and maintenance
  - Document rollback procedures
  - Document monitoring dashboards and alerts
  - _Requirements: Operational documentation_

- [ ] 12.5 Deploy to staging environment
  - Deploy tracking service to staging
  - Deploy web frontend changes to staging
  - Deploy iOS app to TestFlight for internal testing
  - Perform smoke tests
  - _Requirements: Pre-production validation_

- [ ] 12.6 Checkpoint - Validate staging deployment
  - Ensure all tests pass
  - Test tracking end-to-end on staging
  - Verify WebSocket connections work
  - Check ETA calculations are accurate
  - Test messaging integration
  - Ask the user if questions arise or if ready for production deployment

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP delivery
- Each implementation task references specific requirements from requirements.md for traceability
- Backend tasks (1-4) should be completed before frontend tasks (5-10) to enable integration testing
- Web and iOS frontend tasks (5-9) can be developed in parallel after backend is ready
- Testing tasks (11) should be executed continuously as features are implemented
- Deployment tasks (12) should be performed after core functionality is complete and tested
- Checkpoints ensure incremental validation at key milestones
- Google Maps API key must be configured before testing map features
- Redis must be running locally for development
- Consider implementing a feature flag to gradually roll out tracking to users

## Task Dependency Graph

```json
{
  "waves": [
    {
      "id": 0,
      "tasks": ["1.1", "5.1", "8.1"]
    },
    {
      "id": 1,
      "tasks": ["1.2", "1.3", "1.4"]
    },
    {
      "id": 2,
      "tasks": ["1.5", "2.1", "3.1", "3.2"]
    },
    {
      "id": 3,
      "tasks": ["2.2", "3.3", "3.4", "3.5"]
    },
    {
      "id": 4,
      "tasks": ["2.3", "2.4", "4.1"]
    },
    {
      "id": 5,
      "tasks": ["4.2", "4.3", "5.2", "8.2"]
    },
    {
      "id": 6,
      "tasks": ["5.3", "5.4", "5.5", "8.3", "8.4", "8.5"]
    },
    {
      "id": 7,
      "tasks": ["5.6", "5.7", "5.8", "6.1", "8.6", "8.7", "8.8", "9.1"]
    },
    {
      "id": 8,
      "tasks": ["6.2", "6.3", "6.4", "9.2", "9.3"]
    },
    {
      "id": 9,
      "tasks": ["6.5", "7.1", "9.4"]
    },
    {
      "id": 10,
      "tasks": ["7.2", "7.3", "9.5"]
    },
    {
      "id": 11,
      "tasks": ["10.1", "10.2", "10.3"]
    },
    {
      "id": 12,
      "tasks": ["10.4", "11.1", "11.2", "11.3"]
    },
    {
      "id": 13,
      "tasks": ["11.4", "11.5"]
    },
    {
      "id": 14,
      "tasks": ["11.6", "11.7"]
    },
    {
      "id": 15,
      "tasks": ["12.1", "12.2", "12.3"]
    },
    {
      "id": 16,
      "tasks": ["12.4", "12.5"]
    },
    {
      "id": 17,
      "tasks": ["12.6"]
    }
  ]
}
```
