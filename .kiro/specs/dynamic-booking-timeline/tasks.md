# Implementation Tasks: Dynamic Booking Timeline Recalculation

## Task Status Legend
- `[ ]` Not Started
- `[~]` In Progress
- `[x]` Completed
- `[!]` Blocked

---

## Phase 1: Database Schema Changes

### Task 1.1: Create Database Migration for Engagements Table
**Status**: `[x]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 2 hours  
**Dependencies**: None

**Description**:
Create SQL migration to add timeline tracking columns to the `engagements` table.

**Acceptance Criteria**:
- [x] Migration file created: `107_engagement_timeline_recalculation.sql`
- [x] Adds `actual_start_epoch BIGINT` column (nullable)
- [x] Adds `actual_end_epoch BIGINT` column (nullable)
- [x] Adds `duration_minutes INTEGER DEFAULT 60` column
- [x] Adds `is_timeline_recalculated BOOLEAN DEFAULT false` column
- [x] Adds `early_start_minutes INTEGER DEFAULT 0` column
- [x] Includes rollback script
- [x] Tested on development database

**Files Created**:
- `database/sql/107_engagement_timeline_recalculation.sql`

---

### Task 1.2: Create Database Indexes for Timeline Queries
**Status**: `[x]`  
**Priority**: P1  
**Estimated Time**: 1 hour  
**Dependencies**: Task 1.1

**Description**:
Create indexes to optimize timeline-related queries.

**Acceptance Criteria**:
- [x] Index created: `idx_engagements_actual_start` on `actual_start_epoch`
- [x] Index created: `idx_engagements_timeline_recalc` on `is_timeline_recalculated`
- [x] Composite index created: `idx_engagements_status_timeline`
- [x] Index creation is idempotent (IF NOT EXISTS)
- [x] Tested query performance improvement

**Files Modified**:
- `database/sql/107_engagement_timeline_recalculation.sql`

---

### Task 1.3: Update Service Days Table Schema
**Status**: `[x]`  
**Priority**: P1  
**Estimated Time**: 1 hour  
**Dependencies**: Task 1.1

**Description**:
Add actual start time tracking to service_days table.

**Acceptance Criteria**:
- [x] Adds `actual_started_at TIMESTAMP` column (nullable)
- [x] Adds `actual_start_epoch BIGINT` column (nullable)
- [x] Adds `actual_end_epoch BIGINT` column (nullable)
- [x] Index created on `actual_start_epoch`
- [x] Comments added for documentation

**Files Modified**:
- `database/sql/107_engagement_timeline_recalculation.sql`

---

## Phase 2: Backend - Timeline Calculator Module

### Task 2.1: Create Timeline Calculator Service
**Status**: `[x]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 4 hours  
**Dependencies**: Task 1.1

**Description**:
Implement core timeline calculation logic as a reusable service module.

**Acceptance Criteria**:
- [x] Creates `timelineCalculator.js` service
- [x] Implements `captureAndRecalculateTimeline()` function
- [x] Implements `calculateExtension()` function
- [x] Implements `validateTimeline()` function
- [x] Implements `getEffectiveTimeline()` helper
- [x] Includes JSDoc documentation for all functions
- [x] Handles edge cases (extreme early starts, late starts)
- [x] Throws appropriate errors with descriptive messages

**Files Created**:
- `services/payments/src/services/timelineCalculator.js`

---

### Task 2.2: Add Timeline Calculator Unit Tests
**Status**: `[x]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 3 hours  
**Dependencies**: Task 2.1

**Description**:
Write comprehensive unit tests for timeline calculator functions.

**Acceptance Criteria**:
- [x] Test: calculates end time from actual start correctly
- [x] Test: calculates early start minutes correctly
- [x] Test: rejects future start times
- [x] Test: warns on extreme early starts (> 2 hours)
- [x] Test: blocks starts after scheduled end
- [x] Test: extension uses recalculated end time
- [x] Test: handles missing scheduled times gracefully
- [x] Test coverage > 90%

**Files Created**:
- `services/payments/src/services/__tests__/timelineCalculator.test.js`

---

### Task 2.3: Update Engagement Lifecycle Service
**Status**: `[x]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 3 hours  
**Dependencies**: Task 2.1

**Description**:
Integrate timeline calculator into engagement lifecycle transitions.

**Acceptance Criteria**:
- [x] Updates `transitionToInProgress()` function
- [x] Captures `actual_start_epoch` when status changes to IN_PROGRESS
- [x] Calls `captureAndRecalculateTimeline()` in transaction
- [x] Logs timeline modification event
- [x] Maintains backward compatibility
- [x] Includes proper error handling with rollback

**Files Modified**:
- `services/payments/src/services/engagementLifecycle.js`

---

## Phase 3: Backend - API Endpoints

### Task 3.1: Create Start Service Endpoint with Timeline Capture
**Status**: `[x]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 4 hours  
**Dependencies**: Task 2.3

**Description**:
Implement or update endpoint to start service and capture actual start time.

**Acceptance Criteria**:
- [x] Endpoint: `POST /v2/engagements/:id/start` (updated existing)
- [x] Accepts `service_day_id` in request body
- [x] Validates user is assigned service provider
- [x] Updates service_day status to IN_PROGRESS
- [x] Triggers timeline recalculation
- [x] Returns timeline data in response
- [x] Prevents duplicate start attempts
- [x] Handles errors gracefully

**Files Modified**:
- `services/payments/src/routes/engagementService.js`

---

### Task 3.2: Update Extension Endpoint to Use Recalculated Timeline
**Status**: `[x]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 3 hours  
**Dependencies**: Task 2.1

**Description**:
Update extension logic to calculate from recalculated end time.

**Acceptance Criteria**:
- [x] Endpoint uses `actual_end_epoch` if available, else `end_epoch`
- [x] Calculates new end time correctly
- [x] Updates both `end_epoch` and `actual_end_epoch`
- [x] Returns extension charge calculation
- [x] Logs extension modification event
- [x] Validates extension is requested during IN_PROGRESS status

**Files Modified**:
- `services/payments/src/routes/v2/engagementsV2.js` (extension availability check)

---

### Task 3.3: Update Get Engagement Endpoint to Return Timeline Data
**Status**: `[x]`  
**Priority**: P1  
**Estimated Time**: 2 hours  
**Dependencies**: Task 1.1

**Description**:
Modify engagement retrieval to include timeline information.

**Acceptance Criteria**:
- [x] Returns `timeline` object with scheduled and actual times
- [x] Returns `is_timeline_recalculated` flag
- [x] Returns `early_start_minutes` when applicable
- [x] Handles NULL values gracefully
- [x] Maintains backward compatibility with v1 API
- [x] Query performance < 100ms

**Files Modified**:
- `services/payments/src/routes/engagements.js`
- `services/payments/src/routes/service-providers.js`

---

### Task 3.4: Add API Integration Tests
**Status**: `[x]`  
**Priority**: P1  
**Estimated Time**: 4 hours  
**Dependencies**: Tasks 3.1, 3.2, 3.3

**Description**:
Write integration tests for timeline-related API endpoints.

**Acceptance Criteria**:
- [x] Test: POST /start captures actual start time and recalculates
- [x] Test: POST /start prevents duplicate transitions
- [x] Test: POST /start requires provider authorization
- [x] Test: POST /extend uses recalculated end time
- [x] Test: POST /extend calculates correct new end time
- [x] Test: GET /engagements returns timeline data
- [x] Test: Timeline data is consistent across endpoints
- [x] Uses test database transactions for isolation

**Files Created**:
- `services/payments/src/routes/__tests__/timeline-integration.test.js`

---

### Task 3.4: Add API Integration Tests
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 4 hours  
**Dependencies**: Tasks 3.1, 3.2, 3.3

**Description**:
Write integration tests for timeline-related API endpoints.

**Acceptance Criteria**:
- [ ] Test: POST /start captures actual start time and recalculates
- [ ] Test: POST /start prevents duplicate transitions
- [ ] Test: POST /start requires provider authorization
- [ ] Test: POST /extend uses recalculated end time
- [ ] Test: POST /extend calculates correct new end time
- [ ] Test: GET /engagements returns timeline data
- [ ] Test: Timeline data is consistent across endpoints
- [ ] Uses test database transactions for isolation

**Files to Create**:
- `services/payments/src/routes/__tests__/timeline-integration.test.js`

---

## Phase 4: Frontend - iOS App

### Task 4.1: Create Timeline Display Component (iOS)
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 4 hours  
**Dependencies**: Task 3.3

**Description**:
Create reusable component to display booking timeline with recalculation indicators.

**Acceptance Criteria**:
- [ ] Component: `BookingTimelineCard.tsx`
- [ ] Displays actual start/end times when available
- [ ] Falls back to scheduled times when actual times are NULL
- [ ] Shows "X minutes early" badge for early starts
- [ ] Displays duration in readable format
- [ ] Uses theme colors and font sizes
- [ ] Includes accessibility labels
- [ ] Handles loading and error states

**Files to Create**:
- `apps/servease-ios/src/components/BookingTimelineCard.tsx`

---

### Task 4.2: Update Active Booking Screen to Show Recalculated Timeline
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 3 hours  
**Dependencies**: Task 4.1

**Description**:
Integrate timeline component into active booking details screen.

**Acceptance Criteria**:
- [ ] Uses `BookingTimelineCard` component
- [ ] Fetches timeline data from API
- [ ] Updates in real-time when service starts
- [ ] Shows loading skeleton while fetching
- [ ] Handles timeline data not available
- [ ] Maintains existing functionality

**Files to Modify**:
- `apps/servease-ios/src/UserProfile/Bookings.tsx` (or active booking screen)

---

### Task 4.3: Update Extension Dialog to Use Recalculated End Time
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 3 hours  
**Dependencies**: Task 4.1

**Description**:
Update extension UI to preview new end time based on recalculated timeline.

**Acceptance Criteria**:
- [ ] Displays current end time (actual if available)
- [ ] Shows new end time preview for selected extension duration
- [ ] Calculates extension charge correctly
- [ ] Visual indicator showing timeline change
- [ ] Confirms extension with correct parameters
- [ ] Shows success/error feedback

**Files to Modify/Create**:
- `apps/servease-ios/src/components/ExtendBookingDialog.tsx` (or create if doesn't exist)

---

### Task 4.4: Update Booking Card to Show Timeline Status
**Status**: `[ ]`  
**Priority**: P2  
**Estimated Time**: 2 hours  
**Dependencies**: Task 4.1

**Description**:
Add timeline indicators to booking list cards.

**Acceptance Criteria**:
- [ ] Shows "Started early" badge on booking cards
- [ ] Displays actual time range when recalculated
- [ ] Minimal visual changes to existing design
- [ ] Performance: doesn't slow down list rendering
- [ ] Handles missing timeline data gracefully

**Files to Modify**:
- `apps/servease-ios/src/UserProfile/Bookings.tsx` (booking card rendering)

---

## Phase 5: Frontend - Web App

### Task 5.1: Create Timeline Display Component (Web)
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 3 hours  
**Dependencies**: Task 3.3

**Description**:
Create React component for displaying timeline on web app.

**Acceptance Criteria**:
- [ ] Component: `BookingTimeline.tsx`
- [ ] Displays scheduled and actual times
- [ ] Shows alert for early starts
- [ ] Responsive design (mobile and desktop)
- [ ] Uses existing design system components
- [ ] TypeScript types defined
- [ ] Includes Storybook story

**Files to Create**:
- `apps/servase-ui/src/components/BookingTimeline.tsx`
- `apps/servase-ui/src/components/BookingTimeline.stories.tsx`

---

### Task 5.2: Update Booking Details Page (Web)
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 2 hours  
**Dependencies**: Task 5.1

**Description**:
Integrate timeline component into booking details page.

**Acceptance Criteria**:
- [ ] Uses `BookingTimeline` component
- [ ] Fetches timeline data from API
- [ ] Auto-updates when service starts (polling or WebSocket)
- [ ] Shows loading state
- [ ] Error handling with user-friendly messages

**Files to Modify**:
- `apps/servase-ui/src/pages/BookingDetails.tsx` (or equivalent)

---

### Task 5.3: Update Extension Flow (Web)
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 3 hours  
**Dependencies**: Task 5.1

**Description**:
Update web extension dialog to use recalculated timeline.

**Acceptance Criteria**:
- [ ] Shows current end time (recalculated if available)
- [ ] Previews new end time for selected extension
- [ ] Displays extension charge
- [ ] Submits correct extension request
- [ ] Shows success confirmation with new end time

**Files to Modify**:
- `apps/servase-ui/src/components/ExtensionDialog.tsx` (or equivalent)

---

## Phase 6: Billing Integration

### Task 6.1: Update Billing Service to Use Actual Timeline
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 3 hours  
**Dependencies**: Task 1.1

**Description**:
Ensure billing calculations use actual timeline when available.

**Acceptance Criteria**:
- [ ] Uses `actual_start_epoch` and `actual_end_epoch` for billing
- [ ] Falls back to scheduled times if actual times are NULL
- [ ] Extension charges calculated from recalculated end time
- [ ] Generates itemized bill with timeline breakdown
- [ ] Includes both scheduled and actual times in receipts
- [ ] Audit trail includes timeline source

**Files to Modify**:
- `services/payments/src/services/billingService.js` (or equivalent)

---

## Phase 7: Feature Flags & Configuration

### Task 7.1: Implement Feature Flags
**Status**: `[x]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 2 hours  
**Dependencies**: None

**Description**:
Add feature flags to control timeline recalculation rollout.

**Acceptance Criteria**:
- [x] Flag: `ENABLE_TIMELINE_RECALCULATION` (default: false)
- [x] Flag: `ENABLE_RECALCULATED_EXTENSIONS` (default: false, depends on first flag)
- [x] Flag: `ENABLE_TIMELINE_UI_INDICATORS` (default: true)
- [x] Flags configurable per environment
- [x] Flags can be toggled without deployment
- [x] Admin UI to view/toggle flags

**Files Created**:
- `services/payments/src/config/featureFlags.js`
- `services/payments/src/routes/admin/featureFlags.js`

**Files Modified**:
- `services/payments/src/services/engagementLifecycle.js` (integrated feature flag check)

---

## Phase 8: Monitoring & Observability

### Task 8.1: Add Timeline Metrics and Logging
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 3 hours  
**Dependencies**: Task 2.1

**Description**:
Implement monitoring for timeline recalculation operations.

**Acceptance Criteria**:
- [ ] Metric: `timeline.recalculation.count`
- [ ] Metric: `timeline.recalculation.early_start.avg`
- [ ] Metric: `timeline.recalculation.duration`
- [ ] Metric: `timeline.recalculation.errors`
- [ ] Log: Timeline recalculation events with full details
- [ ] Log: Extreme early start warnings (> 2 hours)
- [ ] Log: Extension calculations

**Files to Modify**:
- `services/payments/src/services/timelineCalculator.js`
- `services/payments/src/services/monitoring.js`

---

### Task 8.2: Create Monitoring Dashboard
**Status**: `[ ]`  
**Priority**: P2  
**Estimated Time**: 4 hours  
**Dependencies**: Task 8.1

**Description**:
Set up Grafana dashboard for timeline metrics.

**Acceptance Criteria**:
- [ ] Panel: Timeline recalculation success rate
- [ ] Panel: Average early start minutes
- [ ] Panel: Extension revenue tracking
- [ ] Panel: API latency (P50, P95, P99)
- [ ] Panel: Error rate trends
- [ ] Alerts configured for critical thresholds

**Files to Create**:
- `monitoring/dashboards/timeline-recalculation.json`

---

### Task 8.3: Set Up Alerts
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 2 hours  
**Dependencies**: Task 8.1

**Description**:
Configure alerts for timeline anomalies and errors.

**Acceptance Criteria**:
- [ ] Alert: Extreme early start (> 2 hours) → Slack
- [ ] Alert: Recalculation failure rate > 1% → PagerDuty
- [ ] Alert: Late start after end time → Slack + Email
- [ ] Alert: API latency P95 > 500ms → Slack
- [ ] Alert rules tested in staging

**Files to Create/Modify**:
- `monitoring/alerts/timeline-alerts.yaml`

---

## Phase 9: Documentation

### Task 9.1: Update API Documentation
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 2 hours  
**Dependencies**: Tasks 3.1, 3.2, 3.3

**Description**:
Document new timeline-related API endpoints and response formats.

**Acceptance Criteria**:
- [ ] OpenAPI/Swagger spec updated
- [ ] Request/response examples included
- [ ] Error codes documented
- [ ] Migration guide from v1 to v2 API
- [ ] Published to API documentation portal

**Files to Modify**:
- `docs/api/openapi.yaml`
- `README.md` (API changes section)

---

### Task 9.2: Create User Documentation
**Status**: `[ ]`  
**Priority**: P2  
**Estimated Time**: 3 hours  
**Dependencies**: Phase 4, Phase 5

**Description**:
Write help articles for customers and service providers.

**Acceptance Criteria**:
- [ ] Customer article: "Understanding Your Service Timeline"
- [ ] Provider article: "Starting Services Early"
- [ ] FAQ section with common questions
- [ ] Screenshots from mobile and web apps
- [ ] Published to help center

**Files to Create**:
- `docs/user-guides/timeline-recalculation-customer.md`
- `docs/user-guides/timeline-recalculation-provider.md`

---

### Task 9.3: Write Developer Documentation
**Status**: `[ ]`  
**Priority**: P2  
**Estimated Time**: 2 hours  
**Dependencies**: All implementation tasks

**Description**:
Document technical implementation for internal developers.

**Acceptance Criteria**:
- [ ] Architecture overview diagram
- [ ] Database schema reference
- [ ] Code examples for common use cases
- [ ] Troubleshooting guide
- [ ] Common pitfalls and solutions
- [ ] Published to internal wiki

**Files to Create**:
- `docs/internal/timeline-recalculation-architecture.md`

---

## Phase 10: Testing & Quality Assurance

### Task 10.1: End-to-End Testing
**Status**: `[ ]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 6 hours  
**Dependencies**: All implementation tasks

**Description**:
Write and run comprehensive E2E tests for timeline flows.

**Acceptance Criteria**:
- [ ] Test: SP starts service early, customer sees recalculated time
- [ ] Test: Customer extends from recalculated end time
- [ ] Test: Billing uses actual timeline for charges
- [ ] Test: Timeline data consistent across iOS, Android, Web
- [ ] Test: Edge case: Service starts > 2 hours early
- [ ] Test: Edge case: Extension during active service
- [ ] All tests pass in CI/CD pipeline

**Files to Create**:
- `e2e-tests/timeline-recalculation.spec.ts`

---

### Task 10.2: Manual QA Testing
**Status**: `[ ]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 8 hours  
**Dependencies**: All implementation tasks

**Description**:
Perform manual testing across all platforms and scenarios.

**Test Scenarios**:
- [ ] Service Provider starts service 30 minutes early
- [ ] Service Provider starts service exactly on time
- [ ] Service Provider starts service late (but before end)
- [ ] Customer extends booking from recalculated timeline
- [ ] Customer extends booking multiple times
- [ ] Billing reflects actual timeline correctly
- [ ] Timeline displayed correctly on iOS app
- [ ] Timeline displayed correctly on Android app
- [ ] Timeline displayed correctly on Web app
- [ ] Feature flag toggle disables recalculation
- [ ] Extreme early start (> 2 hours) logs alert
- [ ] Network failure handling during recalculation

**Output**:
- QA test report with pass/fail status
- Bug tickets for any failures

---

### Task 10.3: Performance Testing
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 4 hours  
**Dependencies**: All implementation tasks

**Description**:
Test performance under load and optimize if needed.

**Acceptance Criteria**:
- [ ] API endpoint latency P95 < 500ms under load
- [ ] Database queries complete < 100ms
- [ ] Timeline recalculation completes < 200ms
- [ ] Cache hit rate > 80% for timeline queries
- [ ] No memory leaks in backend services
- [ ] Mobile app UI renders timeline < 100ms

**Tools**:
- Artillery or k6 for load testing
- PostgreSQL EXPLAIN ANALYZE for query optimization

---

## Phase 11: Deployment

### Task 11.1: Deploy Database Migration to Staging
**Status**: `[ ]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 1 hour  
**Dependencies**: Task 1.1

**Description**:
Run database migration in staging environment.

**Acceptance Criteria**:
- [ ] Migration runs successfully without errors
- [ ] All new columns created with correct types
- [ ] Indexes created successfully
- [ ] No performance degradation on existing queries
- [ ] Rollback tested and verified

---

### Task 11.2: Deploy Backend Services to Staging
**Status**: `[ ]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 2 hours  
**Dependencies**: Task 11.1, Phase 2, Phase 3

**Description**:
Deploy updated backend services with feature flags OFF.

**Acceptance Criteria**:
- [ ] All services deployed without errors
- [ ] Health checks passing
- [ ] Feature flags confirmed OFF
- [ ] Smoke tests pass
- [ ] No errors in logs
- [ ] Rollback plan documented

---

### Task 11.3: Deploy Mobile App Updates to TestFlight
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 2 hours  
**Dependencies**: Phase 4

**Description**:
Release iOS app with timeline UI to TestFlight for internal testing.

**Acceptance Criteria**:
- [ ] Build uploaded to TestFlight successfully
- [ ] Internal testers invited
- [ ] Timeline components render correctly
- [ ] No crashes or critical bugs
- [ ] Feedback collected from testers

---

### Task 11.4: Deploy Web App to Staging
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 1 hour  
**Dependencies**: Phase 5

**Description**:
Deploy web app with timeline UI to staging environment.

**Acceptance Criteria**:
- [ ] Deployed successfully
- [ ] Timeline components render correctly
- [ ] No console errors
- [ ] Responsive design works on mobile/desktop
- [ ] API integration working

---

### Task 11.5: Canary Release to Production (5%)
**Status**: `[ ]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 4 hours  
**Dependencies**: Task 11.2, Phase 10

**Description**:
Enable timeline recalculation for 5% of production traffic.

**Acceptance Criteria**:
- [ ] Feature flag enabled for 5% of engagements
- [ ] Monitoring dashboard shows metrics
- [ ] Error rate < 0.5%
- [ ] No customer complaints
- [ ] Timeline data accurate in spot checks
- [ ] Rollback tested and ready

---

### Task 11.6: Gradual Rollout to 100%
**Status**: `[ ]`  
**Priority**: P0 (Blocker)  
**Estimated Time**: 1 week (monitoring)  
**Dependencies**: Task 11.5

**Description**:
Gradually increase feature flag percentage: 5% → 25% → 50% → 75% → 100%

**Acceptance Criteria**:
- [ ] Increase to 25% after 24 hours (no issues)
- [ ] Increase to 50% after 48 hours (no issues)
- [ ] Increase to 75% after 72 hours (no issues)
- [ ] Increase to 100% after 96 hours (no issues)
- [ ] Monitor error rates at each milestone
- [ ] Rollback if error rate > 1%

---

### Task 11.7: Deploy Mobile App to App Store
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 1 week (review time)  
**Dependencies**: Task 11.6

**Description**:
Submit iOS app to App Store after 100% rollout verified.

**Acceptance Criteria**:
- [ ] App submitted for review
- [ ] App Store screenshots updated
- [ ] Release notes include timeline feature
- [ ] App approved and published
- [ ] Monitoring post-launch metrics

---

### Task 11.8: Deploy Web App to Production
**Status**: `[ ]`  
**Priority**: P1  
**Estimated Time**: 1 hour  
**Dependencies**: Task 11.6

**Description**:
Deploy web app with timeline UI to production.

**Acceptance Criteria**:
- [ ] Deployed successfully
- [ ] No errors in production logs
- [ ] Timeline data displays correctly
- [ ] Performance within acceptable limits
- [ ] Monitoring shows healthy metrics

---

## Summary

**Total Tasks**: 43  
**Estimated Total Time**: ~120 hours (~3 weeks for 1 developer)

**Critical Path**:
1. Database Migration (Tasks 1.1-1.3) → 4 hours
2. Timeline Calculator (Tasks 2.1-2.2) → 7 hours
3. API Integration (Tasks 2.3, 3.1-3.3) → 12 hours
4. Testing (Tasks 2.2, 3.4, 10.1-10.3) → 18 hours
5. Deployment (Tasks 11.1-11.8) → Variable (1-2 weeks)

**Priority Breakdown**:
- P0 (Blockers): 17 tasks
- P1 (High): 21 tasks
- P2 (Medium): 5 tasks

**Next Steps**:
1. Review and approve this task list
2. Assign tasks to team members
3. Set up project board (Jira, GitHub Projects, etc.)
4. Begin with Phase 1: Database Schema Changes
