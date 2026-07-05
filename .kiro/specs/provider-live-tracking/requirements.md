# Service Provider Live Tracking - Requirements

## Executive Summary

This document defines requirements for a real-time service provider tracking feature that allows customers to view their provider's live location on a map when the provider is traveling to the service location. The feature will be available on both Web and iOS platforms, providing:

- **Real-time location tracking** with map visualization
- **ETA calculation** showing estimated arrival time
- **In-app messaging** for quick communication during transit  
- **Team service support** with lead provider tracking
- **Offline resilience** with estimated position projection
- **Cross-platform consistency** between Web and iOS

The tracking feature will be accessible from "My Bookings → Today's Services" and will automatically activate when providers begin their journey to the service location. This addresses customer anxiety about provider arrival times and reduces support inquiries.

## Overview
Enable customers to track their service provider's real-time location when the provider is en route to the service location through a dedicated tracking section in "My Bookings → Today's Services" on both Web and iOS platforms.

## Problem Statement
Currently, customers have no visibility into their service provider's location or estimated arrival time when the provider is traveling to the service location. This lack of transparency creates anxiety and uncertainty, leading to:
- Customers not knowing when to be available
- Missed connections due to timing issues
- Increased support inquiries about provider whereabouts
- Poor user experience compared to modern on-demand service apps

## Goals
1. **Primary**: Provide real-time visibility of service provider location during transit
2. **Secondary**: Reduce customer anxiety and support inquiries
3. **Tertiary**: Improve platform competitiveness with modern tracking UX

## Non-Goals
- Historical location tracking or playback
- Provider performance analytics based on routes
- Multi-provider tracking on single map
- Turn-by-turn navigation for customers

## User Stories

### US-1: View Provider Location (Critical)
**As a** customer with a scheduled service today  
**I want to** see my service provider's current location on a map  
**So that** I know when they'll arrive and can prepare accordingly

**Acceptance Criteria:**
- Track button is visible in Today's Services section
- Clicking/tapping Track button opens a full map view
- Provider's current location is displayed as a marker on the map
- Service destination address is displayed as a separate marker
- Map automatically centers to show both provider and destination

### US-2: Real-Time Location Updates (Critical)
**As a** customer tracking my provider  
**I want to** see their location update in real-time  
**So that** I have accurate information about their progress

**Acceptance Criteria:**
- Provider location updates at least every 30 seconds
- Map smoothly animates marker position changes
- Updates continue automatically without user interaction
- Timestamp of last update is displayed
- Loading indicator shown during location fetches

### US-3: Tracking Availability (Critical)
**As a** customer  
**I want to** see when tracking is available  
**So that** I only attempt to track when the provider is actually en route

**Acceptance Criteria:**
- Track button only shown when provider has started journey
- Disabled state shown with explanation when tracking unavailable
- Clear messaging when provider hasn't started yet
- Clear messaging when provider has arrived
- Status updates reflect provider's current state

### US-4: Error Handling (High Priority)
**As a** customer  
**I want to** understand why tracking isn't working  
**So that** I know if it's temporary or if I should contact support

**Acceptance Criteria:**
- Clear error message when location data unavailable
- Retry option for transient failures
- Graceful degradation to last known location
- Contact support option for persistent issues
- Error doesn't crash the app

### US-5: Provider Privacy (High Priority)
**As a** service provider  
**I want** my location tracked only during active bookings  
**So that** my privacy is protected when I'm not working

**Acceptance Criteria:**
- Location tracking automatically starts when service begins
- Location tracking automatically stops when service ends
- Provider can manually stop sharing location if needed
- No location history is retained after service completion
- Clear privacy policy communicated to providers

### US-6: Cross-Platform Consistency (High Priority)
**As a** customer  
**I want** the same tracking experience on web and mobile  
**So that** I have a consistent experience regardless of device

**Acceptance Criteria:**
- UI layout and components similar across platforms
- Same tracking features available on both platforms
- Similar performance characteristics
- Consistent error handling and messaging

### US-7: Network Resilience (Medium Priority)
**As a** customer with unreliable internet  
**I want** tracking to work despite connectivity issues  
**So that** I can still get location updates when possible

**Acceptance Criteria:**
- App caches last known location when offline
- Automatically resumes updates when connectivity restored
- Visual indicator of connection status
- Queued location updates applied when reconnected

### US-8: Battery Optimization (Medium Priority)
**As a** service provider  
**I want** location tracking to minimize battery drain  
**So that** my phone lasts through my work day

**Acceptance Criteria:**
- Location updates use balanced power mode
- Update frequency reduces when provider is stationary
- Background tracking pauses when customer not viewing map
- Provider can see battery impact in settings

### US-9: View ETA (High Priority)
**As a** customer  
**I want to** see when my provider will arrive  
**So that** I can plan my time accordingly

**Acceptance Criteria:**
- ETA displayed prominently on tracking screen (e.g., "Arriving in 15-20 min")
- ETA updates automatically as provider moves
- Shows time range to account for traffic/uncertainty
- Clear messaging when ETA cannot be calculated
- ETA considers current traffic conditions

### US-10: Message Provider During Transit (Medium Priority)
**As a** customer  
**I want to** message my provider while tracking them  
**So that** I can communicate about parking, access codes, or delays without leaving the tracking screen

**Acceptance Criteria:**
- Message button visible on tracking screen
- Opens chat interface without closing map
- Quick message templates available ("Where to park?", "Gate code is...", etc.)
- Provider receives notifications
- Unread message indicator visible

### US-11: Track Team Services (Low Priority)
**As a** customer with a team service booking  
**I want to** see when the team is arriving  
**So that** I know when to be available for the entire team

**Acceptance Criteria:**
- Tracking shows "Team en route" instead of individual name
- Single marker represents the team (lead provider)
- Team member names listed in details panel
- ETA applies to entire team arrival
- Consistent with single-provider UX

## Functional Requirements

### FR-1: Tracking Button Display
- Display "Track Provider" button in Today's Services card for each booking
- Button states:
  - **Enabled**: Provider is en route (between service start and arrival)
  - **Disabled**: Provider not yet started or has already arrived
  - **Hidden**: Booking not scheduled for today or is cancelled
- Button shows loading state while fetching tracking availability

### FR-2: Map View
- Full-screen map view on mobile, modal/drawer on web
- Provider marker with avatar/icon
- Destination marker with customer address
- Current location accuracy indicator (radius circle)
- Zoom controls and re-center button
- Close/back button to return to bookings list

### FR-3: Real-Time Updates
- Location updates via WebSocket connection (preferred) or polling (fallback)
- Update frequency: 15-30 seconds when provider is moving
- Update frequency: 60 seconds when provider is stationary
- Automatic reconnection on connection loss
- Update timestamp displayed to user

### FR-4: Tracking Lifecycle
**Provider States:**
- `not_started`: Booking scheduled but provider hasn't begun journey
- `en_route`: Provider actively traveling to service location
- `arrived`: Provider reached destination
- `in_progress`: Service is being performed
- `completed`: Service finished

**Tracking Availability:**
- Available only when state = `en_route`
- Track button disabled but visible in other states with explanation

### FR-5: Location Data
**Required Fields:**
- `provider_id`: Service provider identifier
- `engagement_id`: Booking identifier
- `latitude`: Current latitude (decimal degrees)
- `longitude`: Current longitude (decimal degrees)
- `accuracy`: Location accuracy in meters
- `timestamp`: Unix epoch timestamp of location reading
- `bearing`: Direction of travel in degrees (0-360, 0=North) - **required for offline estimation**
- `speed`: Speed in m/s - **required for offline estimation**
- `is_team_lead`: Boolean indicating if this is the lead provider for team bookings
- `team_member_count`: Number of providers in team (null if solo)
- `eta_seconds`: Estimated seconds to destination (calculated server-side)
- `distance_meters`: Remaining distance to destination in meters

### FR-6: Permissions Handling
**Web:**
- No location permissions needed (tracking provider, not customer)
- Map loads with internet connection only

**iOS:**
- No location permissions needed from customer
- Provider app must request "While Using App" location permission
- Graceful error if provider denies permission

### FR-7: Map Integration
**Technology:**
- Web: Google Maps JavaScript API or Mapbox GL JS
- iOS: React Native Maps (Google Maps on Android, Apple Maps on iOS)

**Features Required:**
- Marker placement and updates
- Map centering and zoom
- Polyline for route (optional enhancement)
- Smooth marker animation

### FR-8: ETA Calculation and Display
**ETA Calculation:**
- Use routing/directions API (Google Maps Directions, Mapbox Directions)
- Calculate distance and estimated travel time from current location to destination
- Factor in current traffic conditions (when available)
- Recalculate ETA every 2 minutes or when provider deviates significantly from route

**ETA Display:**
- Show as time range (e.g., "15-20 min", "Arriving in 5 min")
- Position prominently on tracking screen (top card or header)
- Update smoothly without jarring changes
- Show "Calculating..." state during computation
- Fallback to distance-only if ETA unavailable (e.g., "2.5 km away")

**ETA States:**
- **Imminent**: "Arriving in 1-2 min" (green indicator)
- **Near**: "Arriving in 5-15 min" (blue indicator)
- **En route**: "Arriving in 15+ min" (default indicator)
- **Unknown**: "Calculating ETA..." or "Distance: X km"

### FR-9: In-App Messaging Integration
**Messaging Button:**
- Floating action button or header button on tracking view
- Opens chat interface overlay (doesn't close map)
- Badge shows unread message count

**Quick Message Templates:**
- "Where should I park?"
- "What's the gate/entry code?"
- "Running a few minutes late"
- "I'm here!"
- Custom message option

**Message Delivery:**
- Integrates with existing chat/messaging system
- Push notifications to provider
- Audio alerts for safety (provider receives voice notification)
- Message history accessible from tracking view

### FR-10: Team Service Tracking
**Team Identification:**
- Detect multiple providers assigned to same booking
- Show "Team" label instead of individual name
- Single marker represents team (lead provider's location)

**Team Display:**
- Team members list in expandable details panel
- Lead provider identified
- Individual statuses if available (e.g., "2 of 3 team members en route")
- Same ETA for all team members

### FR-11: Offline Mode with Position Estimation
**Detection:**
- No location update received for 60 seconds = offline detection
- Distinguish between provider offline vs backend issues

**Estimated Position:**
- Project position along route using:
  - Last known location
  - Last known speed
  - Last known bearing/direction
  - Elapsed time since last update
- Show estimated position as semi-transparent or dotted marker
- Display confidence indicator (decreases over time)

**User Communication:**
- "Last updated X minutes ago" timestamp
- "Estimated location" label on marker
- "Connection lost" banner with retry option
- Automatic reconnection when provider comes back online

**Limitations:**
- Stop projecting after 10 minutes offline
- Show only last known location if no speed/direction data
- Clear disclaimer about estimation accuracy

## Non-Functional Requirements

### NFR-1: Performance
- Map view loads within 2 seconds on 4G connection
- Location updates processed within 500ms of receipt
- Smooth marker animations (60fps)
- Maximum 1MB memory overhead for tracking feature

### NFR-2: Scalability
- Support 1000+ concurrent tracking sessions
- Location updates handled via pub-sub architecture
- Horizontal scaling for WebSocket connections

### NFR-3: Reliability
- 99.5% uptime for tracking service
- Automatic reconnection with exponential backoff
- Graceful degradation when real-time unavailable

### NFR-4: Security
- Location data transmitted over HTTPS/WSS only
- Authentication required for tracking access
- Customer can only track their assigned provider
- Location data encrypted at rest
- Automatic data purging after service completion

### NFR-5: Privacy
- GDPR and data protection compliance
- Location tracking consent from providers
- No location data retention beyond active booking
- Clear privacy policy and terms

### NFR-6: Accessibility
- Screen reader support for tracking status
- High contrast mode for map markers
- Keyboard navigation for web interface
- Text alternatives for visual map elements

## Technical Constraints

### Backend
- Existing Node.js/Express infrastructure
- PostgreSQL database
- Redis for real-time data
- AWS deployment

### Frontend
- Web: React 18+, TypeScript
- iOS: React Native, TypeScript
- Existing design system and component library

### APIs
- RESTful API for initial data
- WebSocket or Server-Sent Events for real-time updates
- Rate limiting: Max 1 location update per 15 seconds per provider

### Maps
- Google Maps API quota considerations
- Mapbox as potential alternative
- Must support both web and mobile

## Success Metrics

### Adoption Metrics
- % of customers who use tracking when available: Target 60%+
- % of bookings with tracking data available: Target 80%+
- Average time spent viewing tracking map: 2-5 minutes
- % of customers who use messaging from tracking view: Target 20%+
- ETA accuracy (actual vs predicted arrival): Target ±5 minutes (80th percentile)

### Performance Metrics
- Map load time: <2 seconds (p95)
- Location update latency: <1 second (p95)
- Update success rate: >95%
- ETA calculation time: <500ms (p95)
- Message delivery time: <2 seconds (p95)

### Business Metrics
- Reduction in "Where is my provider?" support tickets: Target 30%
- Customer satisfaction increase: Target 10% improvement
- Provider no-show rate reduction: Target 15%
- Reduction in "provider can't find location" issues: Target 20%

## Dependencies

### Internal
- Provider mobile app must implement location sharing with speed and bearing
- Backend tracking service infrastructure
- Authentication and authorization system
- WebSocket infrastructure
- **Existing chat/messaging system integration**
- **Routing/directions API integration for ETA calculation**

### External
- Google Maps API (or Mapbox) - including Directions API for ETA
- iOS/Android location permissions from providers
- Network connectivity for real-time updates
- **Google Maps Directions API or equivalent for ETA and route calculation**

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Poor GPS accuracy in dense areas | High | High | Show accuracy radius, use network triangulation, clearly label estimated positions |
| Battery drain on provider devices | High | Medium | Optimize update frequency, use low-power mode, adaptive polling |
| Network connectivity issues | Medium | High | Implement offline caching with position estimation, graceful degradation |
| Privacy concerns from providers | High | Low | Clear communication, consent flows, data policies, auto-purge after completion |
| Map API cost overruns | Medium | Medium | Set usage quotas, optimize API calls (batch ETA requests), consider alternatives |
| WebSocket scaling challenges | High | Medium | Use proven pub-sub infrastructure (Redis), load testing |
| Inaccurate ETA predictions | Medium | High | Show time ranges, recalculate frequently, set user expectations with disclaimers |
| Position estimation errors when offline | Medium | High | Clear "estimated" labeling, stop projecting after 10 min, show confidence indicator |
| Messaging while driving safety concerns | High | Medium | Voice notifications for providers, encourage voice replies, safety warnings |
| Team tracking complexity | Low | Low | Start simple with lead provider only, clear "Team" labeling |

## Design Decisions

### 1. ETA Display ✅
**Decision**: Yes, show estimated time of arrival
- Display ETA prominently on tracking view
- Update ETA as provider moves
- Use routing API to calculate travel time
- Show range (e.g., "15-20 min") to account for uncertainty

### 2. In-App Messaging ✅
**Decision**: Yes, add messaging button in tracking view
- Messaging button visible on tracking screen
- Opens existing chat system or initiates new conversation
- Quick templates for common messages ("Running late", "Can't find parking", etc.)
- Provider receives notifications while driving (voice alerts recommended)

### 3. Multiple Provider Support ✅
**Decision**: Show "Team en route" status, track lead provider only
- Single marker on map representing the team
- Label shows "Team" instead of individual name
- ETA calculated for lead provider
- List of team members shown in details panel

### 4. Provider Offline Handling ✅
**Decision**: Show last location + estimated position based on previous route
- Display last known location with timestamp
- Project estimated position along route using last known speed/direction
- Show "Connection lost" indicator with time elapsed
- Clear visual distinction (grayed marker or pulsing indicator)
- Disclaimer: "Estimated location - last updated X minutes ago"

### 5. Historical Route Data ✅
**Decision**: No historical data - real-time tracking only
- Location data purged immediately after service completion
- No route playback feature
- Privacy-first approach
- Reduces data storage requirements

### 6. Service Type Customization ✅
**Decision**: Same tracking for all service types
- Consistent UX across all services
- Simpler implementation and maintenance
- Providers can send messages if they need to make stops

## Out of Scope (Future Enhancements)
- Route optimization suggestions for providers
- Individual tracking for each team member (track lead only for now)
- Integration with provider navigation apps
- Customer location sharing for complex addresses
- Geofencing alerts when provider approaches
- Multi-stop route tracking for providers with multiple bookings
- Historical route playback (decided against for privacy)
- Service-type specific tracking behavior (using universal approach)
