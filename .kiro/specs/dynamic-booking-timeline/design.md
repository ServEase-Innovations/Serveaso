# Design Document: Dynamic Booking Timeline Recalculation

## 1. Overview

### 1.1 Purpose
This document provides the technical design for implementing dynamic booking timeline recalculation based on actual service start times. When a Service Provider starts a service before the scheduled time, the system will automatically recalculate the end time while preserving the booked duration.

### 1.2 Scope
- Backend API changes for capturing and recalculating timelines
- Database schema modifications
- iOS mobile app UI updates
- Web app UI updates  
- Billing service integration
- Real-time synchronization across platforms

### 1.3 System Context
The feature spans multiple components in the ServEase monorepo:
- **Backend**: `services/payments` - Engagement lifecycle, booking management
- **iOS App**: `apps/servease-ios` - Customer and Service Provider mobile apps
- **Web App**: `apps/servase-ui` - Customer web interface
- **Database**: PostgreSQL with `engagements`, `service_days`, and related tables

## 2. High-Level Architecture

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client Layer                             │
├──────────────────┬──────────────────┬──────────────────────────┤
│   iOS App        │   Android App    │      Web App             │
│  (Customer/SP)   │  (Customer/SP)   │     (Customer)           │
└────────┬─────────┴────────┬─────────┴───────────┬──────────────┘
         │                  │                      │
         └──────────────────┼──────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────────┐
         │      API Gateway / Load Balancer        │
         └──────────────────┬──────────────────────┘
                           │
         ┌─────────────────┴──────────────────────┐
         │                                         │
         ▼                                         ▼
┌────────────────────────┐     ┌────────────────────────┐
│  Engagement Service    │     │   Billing Service      │
│  (Timeline Logic)      │◄────┤   (Charge Calculation) │
└───────┬────────────────┘     └────────────────────────┘
        │
        ▼
┌────────────────────────────────────────────────────────┐
│              Timeline Calculator Module                 │
│  - captureActualStartTime()                            │
│  - recalculateEndTime()                                │
│  - calculateExtensionEndTime()                         │
│  - validateTimeline()                                  │
└───────┬────────────────────────────────────────────────┘
        │
        ▼
┌────────────────────────────────────────────────────────┐
│                  Database Layer                         │
│  Tables: engagements, service_days,                    │
│          engagement_modifications                      │
└────────────────────────────────────────────────────────┘
```

### 2.2 Key Design Principles

1. **Preserve Historical Data**: Store both scheduled and actual timeline data
2. **Duration Immutability**: Booked duration never changes during recalculation
3. **Backward Compatibility**: Existing bookings without actual_start_time use scheduled times
4. **Atomic Updates**: Timeline recalculation happens in a single transaction
5. **Real-time Sync**: All clients receive timeline updates within 2 seconds

## 3. Database Schema Changes

### 3.1 Engagements Table Modifications

```sql
-- Add new columns to track actual start time and recalculated timeline
ALTER TABLE public.engagements
  ADD COLUMN IF NOT EXISTS actual_start_epoch bigint,
  ADD COLUMN IF NOT EXISTS actual_end_epoch bigint,
  ADD COLUMN IF NOT EXISTS duration_minutes integer DEFAULT 60,
  ADD COLUMN IF NOT EXISTS is_timeline_recalculated boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS early_start_minutes integer DEFAULT 0;

-- Add indexes for timeline queries
CREATE INDEX IF NOT EXISTS idx_engagements_actual_start 
  ON public.engagements(actual_start_epoch) 
  WHERE actual_start_epoch IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_engagements_timeline_recalc
  ON public.engagements(is_timeline_recalculated)
  WHERE is_timeline_recalculated = true;

-- Add comment for documentation
COMMENT ON COLUMN public.engagements.actual_start_epoch IS 
  'Unix epoch timestamp when service actually started (captured on IN_PROGRESS transition)';
COMMENT ON COLUMN public.engagements.actual_end_epoch IS
  'Recalculated end epoch: actual_start_epoch + (duration_minutes * 60)';
```


### 3.2 Service Days Table Modifications

```sql
-- Track actual start time at the visit/day level
ALTER TABLE public.service_days
  ADD COLUMN IF NOT EXISTS actual_started_at timestamp without time zone,
  ADD COLUMN IF NOT EXISTS actual_start_epoch bigint,
  ADD COLUMN IF NOT EXISTS actual_end_epoch bigint;

-- Add index for active services
CREATE INDEX IF NOT EXISTS idx_service_days_actual_start
  ON public.service_days(actual_start_epoch)
  WHERE actual_start_epoch IS NOT NULL;

COMMENT ON COLUMN public.service_days.actual_started_at IS
  'Timestamp when service day actually started (may differ from scheduled start_time)';
```

### 3.3 Data Migration Strategy

**Phase 1 - Schema Addition** (Non-breaking):
- Add new columns with NULL defaults
- Existing records remain unchanged
- New bookings continue using scheduled times

**Phase 2 - Backfill** (Optional):
- For completed bookings with `started_at` in service_days, backfill `actual_start_epoch`
- Calculate `duration_minutes` from `start_epoch` and `end_epoch`
- Mark `is_timeline_recalculated = false` for historical data

**Phase 3 - Feature Activation**:
- Enable timeline recalculation logic on IN_PROGRESS transitions
- Monitor for anomalies (extreme early starts)

## 4. API Design

### 4.1 Timeline Recalculation API Endpoint

**Endpoint**: `POST /v2/engagements/:id/start`  
**Purpose**: Start a booking and capture actual start time  
**Actor**: Service Provider

**Request**:
```json
{
  "service_day_id": 12345,
  "start_timestamp": "2026-07-04T13:30:00Z"  // Optional, defaults to NOW()
}
```

**Response**:
```json
{
  "success": true,
  "engagement_id": 67890,
  "timeline": {
    "scheduled_start_epoch": 1720101600,  // 2:00 PM
    "actual_start_epoch": 1720099800,     // 1:30 PM
    "scheduled_end_epoch": 1720105200,    // 3:00 PM
    "actual_end_epoch": 1720103400,       // 2:30 PM
    "duration_minutes": 60,
    "is_timeline_recalculated": true,
    "early_start_minutes": 30
  }
}
```


### 4.2 Extension Calculation API Endpoint

**Endpoint**: `POST /v2/engagements/:id/extend`  
**Purpose**: Extend booking from recalculated end time  
**Actor**: Customer

**Request**:
```json
{
  "extension_minutes": 60
}
```

**Response**:
```json
{
  "success": true,
  "engagement_id": 67890,
  "timeline": {
    "previous_end_epoch": 1720103400,     // 2:30 PM (recalculated)
    "new_end_epoch": 1720107000,          // 3:30 PM (not 4:00 PM!)
    "extension_minutes": 60,
    "extension_charge": 150.00,
    "calculation_base": "recalculated_timeline"
  }
}
```

### 4.3 Get Booking Details API

**Endpoint**: `GET /v2/engagements/:id`  
**Purpose**: Retrieve booking with timeline data  
**Actor**: Customer, Service Provider

**Response**:
```json
{
  "engagement_id": 67890,
  "customer_id": 123,
  "provider_id": 456,
  "service_type": "maid",
  "booking_type": "ON_DEMAND",
  "status": "IN_PROGRESS",
  "timeline": {
    "scheduled": {
      "start_time": "14:00:00",
      "end_time": "15:00:00",
      "start_epoch": 1720101600,
      "end_epoch": 1720105200
    },
    "actual": {
      "start_time": "13:30:00",
      "end_time": "14:30:00",
      "start_epoch": 1720099800,
      "end_epoch": 1720103400
    },
    "duration_minutes": 60,
    "is_recalculated": true,
    "early_start_minutes": 30
  },
  "billing": {
    "base_amount": 300.00,
    "extensions": [],
    "total_amount": 300.00
  }
}
```

## 5. Timeline Calculator Module

### 5.1 Core Functions

**File**: `services/payments/src/services/timelineCalculator.js`

```javascript
/**
 * Captures actual start time and recalculates timeline
 * @param {Object} params
 * @param {number} params.engagement_id
 * @param {number} params.actual_start_epoch - Unix epoch (seconds)
 * @param {Object} params.client - Database transaction client
 * @returns {Promise<Object>} Recalculated timeline
 */
async function captureAndRecalculateTimeline({ 
  engagement_id, 
  actual_start_epoch, 
  client 
}) {
  // 1. Fetch engagement with scheduled timeline
  const engagement = await getEngagement(engagement_id, client);
  
  // 2. Calculate duration from original booking
  const duration_minutes = Math.round(
    (engagement.end_epoch - engagement.start_epoch) / 60
  );
  
  // 3. Calculate new end time
  const actual_end_epoch = actual_start_epoch + (duration_minutes * 60);
  
  // 4. Calculate early start difference
  const early_start_minutes = Math.round(
    (engagement.start_epoch - actual_start_epoch) / 60
  );
  
  // 5. Validate timeline (flag extreme cases)
  await validateTimeline({
    scheduled_start: engagement.start_epoch,
    actual_start: actual_start_epoch,
    duration_minutes
  });
```

  
  // 6. Update database
  await client.query(`
    UPDATE engagements
    SET actual_start_epoch = $1,
        actual_end_epoch = $2,
        duration_minutes = $3,
        is_timeline_recalculated = true,
        early_start_minutes = $4
    WHERE engagement_id = $5
  `, [actual_start_epoch, actual_end_epoch, duration_minutes, 
      early_start_minutes, engagement_id]);
  
  // 7. Log modification event
  await logTimelineModification({
    engagement_id,
    modification_type: 'TIMELINE_RECALCULATED',
    details: { early_start_minutes, duration_minutes },
    client
  });
  
  return {
    scheduled_start_epoch: engagement.start_epoch,
    actual_start_epoch,
    scheduled_end_epoch: engagement.end_epoch,
    actual_end_epoch,
    duration_minutes,
    early_start_minutes
  };
}

/**
 * Calculate extension end time from recalculated timeline
 * @param {Object} params
 * @param {number} params.engagement_id
 * @param {number} params.extension_minutes
 * @param {Object} params.client
 * @returns {Promise<Object>} Extended timeline
 */
async function calculateExtension({
  engagement_id,
  extension_minutes,
  client
}) {
  const engagement = await getEngagement(engagement_id, client);
  
  // Use recalculated end time if available, else scheduled end time
  const base_end_epoch = engagement.actual_end_epoch || engagement.end_epoch;
  const new_end_epoch = base_end_epoch + (extension_minutes * 60);
  
  await client.query(`
    UPDATE engagements
    SET end_epoch = $1,
        actual_end_epoch = $2
    WHERE engagement_id = $3
  `, [new_end_epoch, new_end_epoch, engagement_id]);
  
  return {
    previous_end_epoch: base_end_epoch,
    new_end_epoch,
    extension_minutes
  };
}

/**
 * Validate timeline for edge cases
 * @throws {Error} if timeline is invalid
 */
async function validateTimeline({
  scheduled_start,
  actual_start,
  duration_minutes
}) {
  const diff_minutes = (scheduled_start - actual_start) / 60;
  
  // Alert if more than 2 hours early
  if (diff_minutes > 120) {
    await logAlert({
      type: 'EXTREME_EARLY_START',
      message: `Service started ${diff_minutes} minutes early`,
      severity: 'WARNING'
    });
  }
  
  // Alert if start is after scheduled end
  if (actual_start > scheduled_start + (duration_minutes * 60)) {
    await logAlert({
      type: 'LATE_START_AFTER_END',
      message: 'Service started after scheduled end time',
      severity: 'ERROR'
    });
  }
  
  // Reject future timestamps
  const now = Math.floor(Date.now() / 1000);
  if (actual_start > now + 60) {
    throw new Error('Cannot set start time in the future');
  }
}
```


### 5.2 Integration with Engagement Lifecycle

**File**: `services/payments/src/services/engagementLifecycle.js`

**Modification**: Update `transitionToInProgress` function

```javascript
async function transitionToInProgress(client, { engagementId, serviceDayId }) {
  const now_epoch = Math.floor(Date.now() / 1000);
  
  // 1. Update service_day status
  await client.query(`
    UPDATE service_days
    SET status = 'IN_PROGRESS',
        started_at = NOW(),
        actual_started_at = NOW(),
        actual_start_epoch = $1
    WHERE service_day_id = $2
  `, [now_epoch, serviceDayId]);
  
  // 2. Update engagement status
  await client.query(`
    UPDATE engagements
    SET engagement_status = 'IN_PROGRESS',
        task_status = 'IN_PROGRESS'
    WHERE engagement_id = $1
  `, [engagementId]);
  
  // 3. Capture and recalculate timeline
  const timeline = await captureAndRecalculateTimeline({
    engagement_id: engagementId,
    actual_start_epoch: now_epoch,
    client
  });
  
  // 4. Log lifecycle event
  await logEngagementEvent({
    engagement_id: engagementId,
    event_type: 'SERVICE_STARTED',
    actor_type: 'PROVIDER',
    metadata: { timeline },
    client
  });
  
  return timeline;
}
```

## 6. Frontend Implementation

### 6.1 iOS App - Timeline Display Component

**File**: `apps/servease-ios/src/components/BookingTimelineCard.tsx`

```typescript
interface TimelineData {
  scheduled: {
    start_time: string;
    end_time: string;
    start_epoch: number;
    end_epoch: number;
  };
  actual?: {
    start_time: string;
    end_time: string;
    start_epoch: number;
    end_epoch: number;
  };
  duration_minutes: number;
  is_recalculated: boolean;
  early_start_minutes?: number;
}

const BookingTimelineCard: React.FC<{ timeline: TimelineData }> = ({ 
  timeline 
}) => {
  const displayStart = timeline.actual?.start_time || timeline.scheduled.start_time;
  const displayEnd = timeline.actual?.end_time || timeline.scheduled.end_time;
  const isEarly = timeline.is_recalculated && (timeline.early_start_minutes ?? 0) > 0;
  
  return (
    <View style={styles.timelineCard}>
      <View style={styles.timeRow}>
        <Icon name="clock-start" size={20} color={isEarly ? '#10b981' : '#6b7280'} />
        <Text style={styles.timeLabel}>Started</Text>
        <Text style={styles.timeValue}>{displayStart}</Text>
        {isEarly && (
          <Badge variant="success">
            <Text style={styles.badgeText}>
              {timeline.early_start_minutes}m early
            </Text>
          </Badge>
        )}
      </View>
      
      <View style={styles.timeRow}>
        <Icon name="clock-end" size={20} color="#6b7280" />
        <Text style={styles.timeLabel}>Ends</Text>
        <Text style={styles.timeValue}>{displayEnd}</Text>
      </View>
      
      <View style={styles.durationRow}>
        <Text style={styles.durationText}>
          Duration: {timeline.duration_minutes} minutes
        </Text>
      </View>
    </View>
  );
};
```


### 6.2 iOS App - Extension Dialog

**File**: `apps/servease-ios/src/components/ExtendBookingDialog.tsx`

```typescript
const ExtendBookingDialog: React.FC<{
  booking: Booking;
  onExtend: (minutes: number) => Promise<void>;
}> = ({ booking, onExtend }) => {
  const [selectedMinutes, setSelectedMinutes] = useState(60);
  
  // Use recalculated end time if available
  const currentEndEpoch = booking.timeline.actual?.end_epoch || 
                          booking.timeline.scheduled.end_epoch;
  const newEndEpoch = currentEndEpoch + (selectedMinutes * 60);
  
  const currentEndTime = formatEpochToTime(currentEndEpoch);
  const newEndTime = formatEpochToTime(newEndEpoch);
  
  return (
    <Modal visible={true}>
      <View style={styles.dialogContent}>
        <Text style={styles.title}>Extend Service</Text>
        
        <View style={styles.timelinePreview}>
          <Text style={styles.label}>Current End Time</Text>
          <Text style={styles.time}>{currentEndTime}</Text>
          
          <Icon name="arrow-down" />
          
          <Text style={styles.label}>New End Time</Text>
          <Text style={styles.timeHighlight}>{newEndTime}</Text>
        </View>
        
        <View style={styles.durationSelector}>
          <Text>Extension Duration</Text>
          <Picker selectedValue={selectedMinutes} 
                  onValueChange={setSelectedMinutes}>
            <Picker.Item label="30 minutes" value={30} />
            <Picker.Item label="1 hour" value={60} />
            <Picker.Item label="1.5 hours" value={90} />
            <Picker.Item label="2 hours" value={120} />
          </Picker>
        </View>
        
        <View style={styles.chargeInfo}>
          <Text>Extension Charge: ₹{calculateExtensionCharge(selectedMinutes)}</Text>
        </View>
        
        <Button onPress={() => onExtend(selectedMinutes)}>
          Confirm Extension
        </Button>
      </View>
    </Modal>
  );
};
```

### 6.3 Web App - Timeline Display

**File**: `apps/servase-ui/src/components/BookingTimeline.tsx`

```typescript
import React from 'react';
import { Clock, AlertCircle } from 'lucide-react';

interface TimelineProps {
  timeline: TimelineData;
  status: string;
}

export const BookingTimeline: React.FC<TimelineProps> = ({ 
  timeline, 
  status 
}) => {
  const isActive = status === 'IN_PROGRESS';
  const showActual = timeline.is_recalculated && timeline.actual;
  
  return (
    <div className="booking-timeline">
      <div className="timeline-section">
        <h4 className="section-title">Service Timeline</h4>
        
        {showActual && (
          <div className="alert alert-success">
            <AlertCircle size={16} />
            <span>Service started {timeline.early_start_minutes} minutes early</span>
          </div>
        )}
        
        <div className="time-display">
          <div className="time-row">
            <Clock size={20} />
            <span className="label">Start Time:</span>
            <span className="value">
              {showActual ? timeline.actual.start_time : timeline.scheduled.start_time}
            </span>
            {showActual && (
              <span className="scheduled-hint">
                (scheduled: {timeline.scheduled.start_time})
              </span>
            )}
          </div>
          
          <div className="time-row">
            <Clock size={20} />
            <span className="label">End Time:</span>
            <span className="value">
              {showActual ? timeline.actual.end_time : timeline.scheduled.end_time}
            </span>
          </div>
          
          <div className="duration-row">
            <span>Duration: {timeline.duration_minutes} minutes</span>
          </div>
        </div>
      </div>
    </div>
  );
};
```


## 7. Sequence Diagrams

### 7.1 Service Start with Timeline Recalculation

```
┌──────────┐   ┌─────────┐   ┌────────────┐   ┌──────────┐   ┌──────────┐
│Service   │   │ iOS App │   │  Backend   │   │Timeline  │   │ Database │
│Provider  │   │         │   │   API      │   │Calculator│   │          │
└────┬─────┘   └────┬────┘   └─────┬──────┘   └────┬─────┘   └────┬─────┘
     │              │                │                │              │
     │ Tap "Start   │                │                │              │
     │ Service"     │                │                │              │
     ├─────────────>│                │                │              │
     │              │                │                │              │
     │              │ POST /v2/engagements/:id/start │              │
     │              ├───────────────>│                │              │
     │              │                │                │              │
     │              │                │ BEGIN TRANSACTION             │
     │              │                ├──────────────────────────────>│
     │              │                │                │              │
     │              │                │ UPDATE service_days          │
     │              │                │ SET status='IN_PROGRESS',    │
     │              │                │ actual_start_epoch=NOW()     │
     │              │                ├──────────────────────────────>│
     │              │                │                │              │
     │              │                │ captureAndRecalculateTimeline │
     │              │                ├───────────────>│              │
     │              │                │                │              │
     │              │                │                │ SELECT engagement
     │              │                │                ├─────────────>│
     │              │                │                │              │
     │              │                │                │ Calculate:   │
     │              │                │                │ duration =   │
     │              │                │                │ (end-start)/60
     │              │                │                │              │
     │              │                │                │ Calculate:   │
     │              │                │                │ actual_end = │
     │              │                │                │ actual_start+│
     │              │                │                │ duration*60  │
     │              │                │                │              │
     │              │                │                │ UPDATE engagements
     │              │                │                ├─────────────>│
     │              │                │                │              │
     │              │                │ <timeline>     │              │
     │              │                │<───────────────┤              │
     │              │                │                │              │
     │              │                │ COMMIT TRANSACTION            │
     │              │                ├──────────────────────────────>│
     │              │                │                │              │
     │              │ { success: true, timeline: {...} }           │
     │              │<───────────────┤                │              │
     │              │                │                │              │
     │ "Started at  │                │                │              │
     │ 1:30 PM      │                │                │              │
     │ Ends at 2:30"│                │                │              │
     │<─────────────┤                │                │              │
     │              │                │                │              │
```


### 7.2 Extension from Recalculated Timeline

```
┌──────────┐   ┌─────────┐   ┌────────────┐   ┌──────────┐   ┌──────────┐
│Customer  │   │ iOS App │   │  Backend   │   │Timeline  │   │ Database │
│          │   │         │   │   API      │   │Calculator│   │          │
└────┬─────┘   └────┬────┘   └─────┬──────┘   └────┬─────┘   └────┬─────┘
     │              │                │                │              │
     │ Tap "Extend  │                │                │              │
     │ by 1 hour"   │                │                │              │
     ├─────────────>│                │                │              │
     │              │                │                │              │
     │              │ POST /v2/engagements/:id/extend │             │
     │              │ { extension_minutes: 60 }       │              │
     │              ├───────────────>│                │              │
     │              │                │                │              │
     │              │                │ calculateExtension            │
     │              │                ├───────────────>│              │
     │              │                │                │              │
     │              │                │                │ SELECT engagement
     │              │                │                │ (get actual_end_epoch)
     │              │                │                ├─────────────>│
     │              │                │                │              │
     │              │                │                │ Calculate:   │
     │              │                │                │ new_end =    │
     │              │                │                │ actual_end + │
     │              │                │                │ 60*60        │
     │              │                │                │              │
     │              │                │                │ UPDATE engagements
     │              │                │                │ SET end_epoch,
     │              │                │                │ actual_end_epoch
     │              │                │                ├─────────────>│
     │              │                │                │              │
     │              │                │ <new timeline> │              │
     │              │                │<───────────────┤              │
     │              │                │                │              │
     │              │ { new_end_epoch: ..., charge: 150 }          │
     │              │<───────────────┤                │              │
     │              │                │                │              │
     │ "Extended to │                │                │              │
     │ 3:30 PM      │                │                │              │
     │ Charge: ₹150"│                │                │              │
     │<─────────────┤                │                │              │
     │              │                │                │              │
```

## 8. State Machine

### 8.1 Booking Timeline States

```
┌─────────────────┐
│   SCHEDULED     │  • scheduled_start_time set
│                 │  • actual_start_time = NULL
└────────┬────────┘  • is_timeline_recalculated = false
         │
         │ SP clicks "Start Service"
         ▼
┌─────────────────┐
│  IN_PROGRESS    │  • actual_start_time captured
│  (Recalculated) │  • actual_end_time calculated
└────────┬────────┘  • is_timeline_recalculated = true
         │            • early_start_minutes set
         │
         │ Customer extends OR time reaches actual_end_time
         ▼
┌─────────────────┐
│  IN_PROGRESS    │  • actual_end_time updated
│  (Extended)     │  • extension logged
└────────┬────────┘
         │
         │ SP clicks "Complete" OR time reaches end
         ▼
┌─────────────────┐
│   COMPLETED     │  • Final timeline preserved
│                 │  • Billing uses actual timeline
└─────────────────┘
```


## 9. Data Flow

### 9.1 Timeline Data Propagation

```
┌───────────────────────────────────────────────────────────────┐
│                     Service Start Event                        │
│  (Service Provider clicks "Start Service" at 1:30 PM)         │
└──────────────────────────┬────────────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────┐
         │  1. Capture actual_start_epoch      │
         │     = 1720099800 (1:30 PM)          │
         └──────────────┬──────────────────────┘
                        │
                        ▼
         ┌─────────────────────────────────────┐
         │  2. Calculate duration_minutes      │
         │     = (end_epoch - start_epoch) / 60│
         │     = (1720105200 - 1720101600) / 60│
         │     = 60 minutes                    │
         └──────────────┬──────────────────────┘
                        │
                        ▼
         ┌─────────────────────────────────────┐
         │  3. Calculate actual_end_epoch      │
         │     = actual_start + (duration * 60)│
         │     = 1720099800 + 3600             │
         │     = 1720103400 (2:30 PM)          │
         └──────────────┬──────────────────────┘
                        │
                        ▼
         ┌─────────────────────────────────────┐
         │  4. Calculate early_start_minutes   │
         │     = (scheduled - actual) / 60     │
         │     = (1720101600 - 1720099800) / 60│
         │     = 30 minutes                    │
         └──────────────┬──────────────────────┘
                        │
                        ▼
         ┌─────────────────────────────────────┐
         │  5. Update Database (Atomic)        │
         │     • actual_start_epoch            │
         │     • actual_end_epoch              │
         │     • duration_minutes              │
         │     • is_timeline_recalculated=true │
         │     • early_start_minutes           │
         └──────────────┬──────────────────────┘
                        │
                        ├───────────────┬──────────────┬──────────────┐
                        │               │              │              │
                        ▼               ▼              ▼              ▼
         ┌─────────────────┐ ┌──────────────┐ ┌─────────────┐ ┌────────────┐
         │   iOS App       │ │  Android App │ │   Web App   │ │  Billing   │
         │  (Real-time     │ │  (Real-time  │ │  (Polling/  │ │  Service   │
         │   update via    │ │   update via │ │   WebSocket)│ │            │
         │   API response) │ │   API resp.) │ │             │ │            │
         └─────────────────┘ └──────────────┘ └─────────────┘ └────────────┘
```

### 9.2 Extension Data Flow

```
┌───────────────────────────────────────────────────────────────┐
│              Customer Extends by 60 minutes                    │
│            (Current end time: 2:30 PM recalculated)           │
└──────────────────────────┬────────────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────┐
         │  1. Fetch current actual_end_epoch  │
         │     = 1720103400 (2:30 PM)          │
         │     NOT scheduled end (3:00 PM)     │
         └──────────────┬──────────────────────┘
                        │
                        ▼
         ┌─────────────────────────────────────┐
         │  2. Calculate new_end_epoch         │
         │     = current_end + (extension * 60)│
         │     = 1720103400 + 3600             │
         │     = 1720107000 (3:30 PM)          │
         │     NOT 4:00 PM!                    │
         └──────────────┬──────────────────────┘
                        │
                        ▼
         ┌─────────────────────────────────────┐
         │  3. Calculate extension_charge      │
         │     = (rate_per_hour / 60) * 60     │
         │     = ₹150                          │
         └──────────────┬──────────────────────┘
                        │
                        ▼
         ┌─────────────────────────────────────┐
         │  4. Update Database                 │
         │     • end_epoch = 1720107000        │
         │     • actual_end_epoch = 1720107000 │
         │  5. Log modification                │
         │     • type: "EXTENDED"              │
         │     • extension_minutes: 60         │
         └──────────────┬──────────────────────┘
                        │
                        ▼
         ┌─────────────────────────────────────┐
         │  6. Update Billing                  │
         │     • Add extension line item       │
         │     • Charge: ₹150                  │
         └─────────────────────────────────────┘
```


## 10. Edge Cases and Error Handling

### 10.1 Edge Case Matrix

| Scenario | Detection | Handling |
|----------|-----------|----------|
| **Service starts > 2 hours early** | `early_start_minutes > 120` | Log WARNING alert, allow recalculation, flag for manual review |
| **Service starts after scheduled end** | `actual_start > scheduled_end` | Log ERROR alert, block recalculation, require manual intervention |
| **Service starts in future** | `actual_start > NOW() + 60` | Reject with 400 error: "Invalid start time" |
| **Duplicate IN_PROGRESS transition** | Check existing `actual_start_epoch != NULL` | Prevent overwrite, return existing timeline |
| **Extension before service starts** | Status != 'IN_PROGRESS' | Reject with 400 error: "Cannot extend before service starts" |
| **Negative duration calculation** | `end_epoch < start_epoch` | Log ERROR, fallback to scheduled times |
| **Missing scheduled times** | `start_epoch IS NULL` | Cannot recalculate, use current times as baseline |
| **Database transaction failure** | SQL exception during recalculation | Rollback, return 500 error, preserve scheduled times |

### 10.2 Validation Rules

**Actual Start Time Validation**:
```javascript
function validateActualStartTime(actual_start, scheduled_start, scheduled_end) {
  const now = Math.floor(Date.now() / 1000);
  
  // Rule 1: Cannot be in the future (with 60s tolerance)
  if (actual_start > now + 60) {
    throw new ValidationError('Start time cannot be in the future');
  }
  
  // Rule 2: Warn if > 2 hours before scheduled
  const early_seconds = scheduled_start - actual_start;
  if (early_seconds > 7200) {
    logger.warn('Extreme early start detected', {
      early_minutes: early_seconds / 60,
      scheduled_start,
      actual_start
    });
  }
  
  // Rule 3: Block if starts after scheduled end
  if (actual_start > scheduled_end) {
    throw new ValidationError(
      'Service cannot start after scheduled end time'
    );
  }
  
  // Rule 4: Warn if > 24 hours in the past
  if (now - actual_start > 86400) {
    logger.warn('Start time is > 24 hours in the past', {
      actual_start,
      now
    });
  }
}
```

### 10.3 Fallback Strategy

If timeline recalculation fails at any step:

1. **Catch Exception**: Log full error details with engagement_id
2. **Rollback Transaction**: Ensure database consistency
3. **Fallback to Scheduled Times**: Use original `start_epoch` and `end_epoch`
4. **Set Flag**: `is_timeline_recalculated = false`
5. **Notify Monitoring**: Send alert to error tracking (e.g., Sentry)
6. **Return Gracefully**: API returns success with scheduled timeline
7. **Manual Review**: Flag engagement for admin review

```javascript
try {
  timeline = await captureAndRecalculateTimeline({...});
} catch (error) {
  logger.error('Timeline recalculation failed', {
    engagement_id,
    error: error.message,
    stack: error.stack
  });
  
  await monitoringService.captureException(error, {
    engagement_id,
    scheduled_start,
    actual_start
  });
  
  // Fallback: return scheduled timeline
  timeline = {
    scheduled_start_epoch: engagement.start_epoch,
    actual_start_epoch: null,
    scheduled_end_epoch: engagement.end_epoch,
    actual_end_epoch: null,
    duration_minutes: calculateDuration(engagement),
    is_recalculated: false,
    fallback_reason: 'RECALCULATION_FAILED'
  };
}
```


## 11. Testing Strategy

### 11.1 Unit Tests

**Backend - Timeline Calculator**:
```javascript
describe('Timeline Calculator', () => {
  test('calculates end time from actual start', () => {
    const result = calculateActualEndTime({
      actual_start_epoch: 1720099800,  // 1:30 PM
      duration_minutes: 60
    });
    expect(result).toBe(1720103400);  // 2:30 PM
  });
  
  test('calculates early start minutes correctly', () => {
    const result = calculateEarlyStartMinutes({
      scheduled_start: 1720101600,  // 2:00 PM
      actual_start: 1720099800       // 1:30 PM
    });
    expect(result).toBe(30);
  });
  
  test('rejects future start times', () => {
    const future = Math.floor(Date.now() / 1000) + 3600;
    expect(() => {
      validateActualStartTime(future, future - 3600, future);
    }).toThrow('Start time cannot be in the future');
  });
  
  test('extension uses recalculated end time', () => {
    const result = calculateExtensionEndTime({
      actual_end_epoch: 1720103400,  // 2:30 PM (recalculated)
      extension_minutes: 60
    });
    expect(result).toBe(1720107000);  // 3:30 PM (NOT 4:00 PM)
  });
});
```

### 11.2 Integration Tests

**Backend API**:
```javascript
describe('POST /v2/engagements/:id/start', () => {
  test('starts service and recalculates timeline', async () => {
    const response = await request(app)
      .post('/v2/engagements/12345/start')
      .send({ service_day_id: 67890 })
      .expect(200);
    
    expect(response.body.timeline).toMatchObject({
      is_timeline_recalculated: true,
      duration_minutes: 60,
      early_start_minutes: expect.any(Number)
    });
    
    // Verify database update
    const engagement = await db.query(
      'SELECT * FROM engagements WHERE engagement_id = $1',
      [12345]
    );
    expect(engagement.rows[0].actual_start_epoch).toBeTruthy();
    expect(engagement.rows[0].actual_end_epoch).toBeTruthy();
  });
  
  test('prevents duplicate IN_PROGRESS transitions', async () => {
    // First start
    await request(app)
      .post('/v2/engagements/12345/start')
      .send({ service_day_id: 67890 })
      .expect(200);
    
    // Second start attempt
    const response = await request(app)
      .post('/v2/engagements/12345/start')
      .send({ service_day_id: 67890 })
      .expect(400);
    
    expect(response.body.error).toContain('already started');
  });
});

describe('POST /v2/engagements/:id/extend', () => {
  test('extends from recalculated end time', async () => {
    // Setup: Start service early
    await startServiceEarly(12345, 30); // 30 min early
    
    // Extend by 60 minutes
    const response = await request(app)
      .post('/v2/engagements/12345/extend')
      .send({ extension_minutes: 60 })
      .expect(200);
    
    // Verify new end time is based on recalculated, not scheduled
    const originalScheduledEnd = 1720105200;  // 3:00 PM
    const recalculatedEnd = 1720103400;       // 2:30 PM (30 min early)
    const expectedNewEnd = recalculatedEnd + 3600;  // 3:30 PM
    
    expect(response.body.timeline.new_end_epoch).toBe(expectedNewEnd);
    expect(response.body.timeline.new_end_epoch).not.toBe(
      originalScheduledEnd + 3600  // Would be 4:00 PM - WRONG!
    );
  });
});
```

### 11.3 End-to-End Tests

**Mobile App Flow**:
```typescript
describe('Early Service Start Flow', () => {
  test('SP starts early, customer sees recalculated timeline', async () => {
    // 1. Service Provider starts service 30 min early
    await serviceProviderApp.navigate('/bookings/12345');
    await serviceProviderApp.tap('Start Service');
    await serviceProviderApp.expectToSee('Service started');
    
    // 2. Customer opens booking details
    await customerApp.navigate('/bookings/12345');
    const timeline = await customerApp.getTimeline();
    
    // 3. Verify recalculated timeline is displayed
    expect(timeline.startTime).toBe('1:30 PM');
    expect(timeline.endTime).toBe('2:30 PM');
    expect(timeline.badge).toBe('30m early');
    
    // 4. Customer extends service
    await customerApp.tap('Extend Service');
    await customerApp.selectDuration('1 hour');
    await customerApp.tap('Confirm Extension');
    
    // 5. Verify new end time is correct
    const updatedTimeline = await customerApp.getTimeline();
    expect(updatedTimeline.endTime).toBe('3:30 PM'); // NOT 4:00 PM
    expect(updatedTimeline.charge).toBe('₹150');
  });
});
```


## 12. Performance Considerations

### 12.1 Database Indexing

**Critical Indexes**:
```sql
-- Query active bookings with recalculated timelines
CREATE INDEX idx_engagements_timeline_active 
  ON engagements(actual_start_epoch, is_timeline_recalculated)
  WHERE task_status = 'IN_PROGRESS';

-- Query bookings by actual end time for notifications
CREATE INDEX idx_engagements_actual_end
  ON engagements(actual_end_epoch)
  WHERE actual_end_epoch IS NOT NULL;

-- Composite index for common queries
CREATE INDEX idx_engagements_status_timeline
  ON engagements(task_status, is_timeline_recalculated, actual_end_epoch);
```

### 12.2 Query Optimization

**Before** (N+1 queries problem):
```javascript
// Inefficient: Fetches timeline data in separate queries
const bookings = await getActiveBookings();
for (const booking of bookings) {
  booking.timeline = await getTimelineData(booking.id);
}
```

**After** (Single query with JOIN):
```javascript
// Efficient: Fetches all timeline data in one query
const bookings = await db.query(`
  SELECT 
    e.engagement_id,
    e.start_epoch AS scheduled_start,
    e.end_epoch AS scheduled_end,
    e.actual_start_epoch,
    e.actual_end_epoch,
    e.duration_minutes,
    e.is_timeline_recalculated,
    e.early_start_minutes
  FROM engagements e
  WHERE e.task_status = 'IN_PROGRESS'
    AND e.customerid = $1
`);
```

### 12.3 Caching Strategy

**Timeline Data Caching**:
- **Cache Key**: `timeline:engagement:{engagement_id}`
- **TTL**: 60 seconds (balance freshness vs performance)
- **Invalidation**: On timeline recalculation or extension

```javascript
async function getEngagementTimeline(engagement_id) {
  const cacheKey = `timeline:engagement:${engagement_id}`;
  
  // Try cache first
  let timeline = await cache.get(cacheKey);
  if (timeline) {
    return JSON.parse(timeline);
  }
  
  // Fetch from database
  timeline = await db.query(`
    SELECT 
      start_epoch, end_epoch,
      actual_start_epoch, actual_end_epoch,
      duration_minutes, is_timeline_recalculated,
      early_start_minutes
    FROM engagements
    WHERE engagement_id = $1
  `, [engagement_id]);
  
  // Cache for 60 seconds
  await cache.setex(cacheKey, 60, JSON.stringify(timeline));
  
  return timeline;
}

async function invalidateTimelineCache(engagement_id) {
  const cacheKey = `timeline:engagement:${engagement_id}`;
  await cache.del(cacheKey);
}
```

### 12.4 Real-time Update Performance

**WebSocket Broadcast Optimization**:
```javascript
// Only broadcast to relevant clients
async function broadcastTimelineUpdate(engagement_id, timeline) {
  const engagement = await getEngagement(engagement_id);
  
  // Identify relevant clients
  const recipients = [
    `customer:${engagement.customerid}`,
    `provider:${engagement.serviceproviderid}`
  ];
  
  // Broadcast only to these clients
  await webSocketServer.broadcastToRooms(recipients, {
    type: 'TIMELINE_UPDATED',
    engagement_id,
    timeline
  });
}
```

## 13. Monitoring and Observability

### 13.1 Key Metrics

**Timeline Recalculation Metrics**:
- `timeline.recalculation.count` - Total recalculations
- `timeline.recalculation.early_start.avg` - Average early start minutes
- `timeline.recalculation.duration` - Time to complete recalculation
- `timeline.recalculation.errors` - Failed recalculation attempts

**Extension Metrics**:
- `timeline.extension.count` - Total extensions
- `timeline.extension.from_recalculated.count` - Extensions using recalculated end
- `timeline.extension.revenue` - Revenue from extensions

### 13.2 Logging

**Timeline Event Logging**:
```javascript
logger.info('Timeline recalculated', {
  engagement_id: 12345,
  scheduled_start: '2024-07-04T14:00:00Z',
  actual_start: '2024-07-04T13:30:00Z',
  scheduled_end: '2024-07-04T15:00:00Z',
  actual_end: '2024-07-04T14:30:00Z',
  duration_minutes: 60,
  early_start_minutes: 30,
  is_recalculated: true
});
```

### 13.3 Alerts

**Critical Alerts**:
- **Extreme Early Start**: `early_start_minutes > 120`
- **Late Start After End**: `actual_start > scheduled_end`
- **Recalculation Failure Rate**: `> 1% of attempts`
- **Extension Calculation Error**: Any exception during extension

**Alert Configuration**:
```yaml
alerts:
  - name: extreme_early_start
    condition: early_start_minutes > 120
    severity: warning
    notification: slack
    
  - name: timeline_recalc_failures
    condition: error_rate > 0.01
    severity: critical
    notification: pagerduty
    
  - name: late_start_after_end
    condition: actual_start > scheduled_end
    severity: error
    notification: slack, email
```


## 14. Deployment Strategy

### 14.1 Phased Rollout Plan

**Phase 1: Database Schema (Week 1)**
- Deploy schema changes (new columns with NULL defaults)
- No functionality changes - zero impact
- Verify database migration success across all environments
- Rollback plan: DROP COLUMN (safe since columns are nullable and unused)

**Phase 2: Backend API (Week 2)**
- Deploy timeline calculator module
- Deploy updated engagement lifecycle service
- Feature flag: `ENABLE_TIMELINE_RECALCULATION` = false (OFF)
- Deploy to staging, run integration tests
- Monitor for any regressions in existing flows
- Rollback plan: Revert to previous service version

**Phase 3: Canary Release (Week 3)**
- Enable feature for 5% of bookings
- Monitor metrics: recalculation success rate, errors, performance
- Verify timeline data accuracy through manual spot checks
- Collect feedback from early users
- Rollback plan: Set feature flag to false

**Phase 4: Gradual Rollout (Week 4)**
- Increase to 25%, 50%, 75% over 3 days
- Monitor error rates and user feedback at each milestone
- If error rate < 0.5% and no critical issues: proceed
- If error rate > 1%: pause rollout, investigate

**Phase 5: Full Release (Week 5)**
- Enable for 100% of bookings
- Update mobile apps to display recalculated timelines
- Update web app to display recalculated timelines
- Announce feature to users

### 14.2 Feature Flag Configuration

```javascript
// Feature flag service
const TIMELINE_FEATURES = {
  ENABLE_TIMELINE_RECALCULATION: {
    default: false,
    environments: {
      development: true,
      staging: true,
      production: false  // Initially off in production
    }
  },
  ENABLE_RECALCULATED_EXTENSIONS: {
    default: false,
    dependencies: ['ENABLE_TIMELINE_RECALCULATION']
  },
  ENABLE_TIMELINE_UI_INDICATORS: {
    default: true  // Safe to enable UI even if recalc is off
  }
};

// Usage in code
async function startService(engagement_id) {
  const shouldRecalculate = await featureFlags.isEnabled(
    'ENABLE_TIMELINE_RECALCULATION',
    { engagement_id }
  );
  
  if (shouldRecalculate) {
    await captureAndRecalculateTimeline(engagement_id);
  } else {
    // Existing behavior: just update status
    await updateStatus(engagement_id, 'IN_PROGRESS');
  }
}
```

### 14.3 Rollback Procedures

**Immediate Rollback (< 5 minutes)**:
```bash
# Disable feature flag globally
curl -X POST https://api.servease.in/admin/feature-flags \
  -d '{"feature": "ENABLE_TIMELINE_RECALCULATION", "enabled": false}'
```

**Service Rollback (< 15 minutes)**:
```bash
# Revert to previous Docker image
kubectl rollout undo deployment/payments-service

# Verify rollback success
kubectl rollout status deployment/payments-service
```

**Database Rollback (if needed)**:
```sql
-- Rollback timeline recalculations
UPDATE engagements
SET is_timeline_recalculated = false,
    actual_start_epoch = NULL,
    actual_end_epoch = NULL,
    early_start_minutes = 0
WHERE is_timeline_recalculated = true
  AND created_at > '2026-07-01';  -- Only recent ones

-- Drop indexes if causing performance issues
DROP INDEX IF EXISTS idx_engagements_actual_start;
DROP INDEX IF EXISTS idx_engagements_timeline_recalc;
```

## 15. Security Considerations

### 15.1 Authorization

**Timeline Modification Authorization**:
- Only Service Provider can trigger IN_PROGRESS transition
- Only Customer can request extensions
- Admin can manually adjust timelines with audit log

```javascript
// Authorization middleware
async function authorizeTimelineModification(req, res, next) {
  const { engagement_id } = req.params;
  const { actor_type, actor_id } = req.auth;
  
  const engagement = await getEngagement(engagement_id);
  
  // Service Provider can start service
  if (req.path.endsWith('/start')) {
    if (actor_type !== 'PROVIDER' || 
        actor_id !== engagement.serviceproviderid) {
      return res.status(403).json({ 
        error: 'Only assigned provider can start service' 
      });
    }
  }
  
  // Customer can extend service
  if (req.path.endsWith('/extend')) {
    if (actor_type !== 'CUSTOMER' || 
        actor_id !== engagement.customerid) {
      return res.status(403).json({ 
        error: 'Only booking customer can extend service' 
      });
    }
  }
  
  next();
}
```

### 15.2 Input Validation

**Timeline Input Sanitization**:
```javascript
function validateTimelineInput(input) {
  // Validate actual_start_epoch
  if (input.actual_start_epoch) {
    if (!Number.isInteger(input.actual_start_epoch)) {
      throw new ValidationError('actual_start_epoch must be integer');
    }
    if (input.actual_start_epoch < 0) {
      throw new ValidationError('actual_start_epoch must be positive');
    }
    // Max 2 years in the past
    const twoYearsAgo = Math.floor(Date.now() / 1000) - (2 * 365 * 24 * 60 * 60);
    if (input.actual_start_epoch < twoYearsAgo) {
      throw new ValidationError('actual_start_epoch too far in the past');
    }
  }
  
  // Validate extension_minutes
  if (input.extension_minutes) {
    if (!Number.isInteger(input.extension_minutes)) {
      throw new ValidationError('extension_minutes must be integer');
    }
    if (input.extension_minutes < 15 || input.extension_minutes > 480) {
      throw new ValidationError('extension_minutes must be 15-480');
    }
  }
}
```

### 15.3 Rate Limiting

**Timeline API Rate Limits**:
```javascript
const RATE_LIMITS = {
  '/v2/engagements/:id/start': {
    window: '1m',
    max: 3  // Max 3 attempts per minute (prevents abuse)
  },
  '/v2/engagements/:id/extend': {
    window: '5m',
    max: 5  // Max 5 extensions per 5 minutes
  }
};
```


## 16. Backward Compatibility

### 16.1 API Versioning

**v1 API (Existing - No Changes)**:
```
GET /engagements/:id
Response: {
  start_time: "14:00:00",
  end_time: "15:00:00",
  start_epoch: 1720101600,
  end_epoch: 1720105200
}
```

**v2 API (New - With Timeline)**:
```
GET /v2/engagements/:id
Response: {
  timeline: {
    scheduled: {...},
    actual: {...},
    is_recalculated: true
  }
}
```

Mobile and web apps can migrate to v2 gradually without breaking v1 clients.

### 16.2 Database Compatibility

**Null-safe Queries**:
```sql
-- Get effective start time (actual if available, else scheduled)
SELECT 
  COALESCE(actual_start_epoch, start_epoch) AS effective_start,
  COALESCE(actual_end_epoch, end_epoch) AS effective_end,
  COALESCE(is_timeline_recalculated, false) AS is_recalculated
FROM engagements
WHERE engagement_id = $1;
```

**Graceful Fallback**:
```javascript
function getEffectiveTimeline(engagement) {
  if (engagement.is_timeline_recalculated && engagement.actual_start_epoch) {
    return {
      start: engagement.actual_start_epoch,
      end: engagement.actual_end_epoch,
      is_recalculated: true
    };
  }
  
  // Fallback to scheduled times
  return {
    start: engagement.start_epoch,
    end: engagement.end_epoch,
    is_recalculated: false
  };
}
```

## 17. Documentation Requirements

### 17.1 API Documentation

**OpenAPI/Swagger Spec Update**:
```yaml
/v2/engagements/{id}/start:
  post:
    summary: Start a booking and capture actual start time
    description: |
      Transitions booking to IN_PROGRESS and captures the actual service start time.
      Automatically recalculates end time while preserving booked duration.
    parameters:
      - name: id
        in: path
        required: true
        schema:
          type: integer
        description: Engagement ID
    requestBody:
      content:
        application/json:
          schema:
            type: object
            properties:
              service_day_id:
                type: integer
                description: Service day to start
    responses:
      200:
        description: Service started successfully
        content:
          application/json:
            schema:
              type: object
              properties:
                success:
                  type: boolean
                engagement_id:
                  type: integer
                timeline:
                  $ref: '#/components/schemas/Timeline'
      400:
        description: Invalid request or service already started
      403:
        description: Unauthorized - only assigned provider can start
```

### 17.2 User Documentation

**Customer Help Article**: "Understanding Your Service Timeline"
- Explains how actual start time affects end time
- Visual examples of early starts and extensions
- FAQ section addressing common questions

**Service Provider Guide**: "Starting Services Early"
- Instructions on how early starts are handled
- Impact on service end time
- Payment implications

### 17.3 Developer Documentation

**Internal Wiki**: "Timeline Recalculation Architecture"
- System design overview
- Database schema reference
- API integration guide
- Troubleshooting guide
- Common pitfalls and solutions

## 18. Success Metrics

### 18.1 Technical Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Timeline recalculation success rate | > 99.5% | Successful recalcs / Total attempts |
| API response time (P95) | < 500ms | `/v2/engagements/:id/start` latency |
| Extension calculation accuracy | 100% | Manual audit of extension end times |
| Database query performance | < 100ms | Timeline query P95 latency |
| Real-time update delivery | < 2s | Time from backend update to client display |

### 18.2 Business Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| User confusion reduction | 50% decrease | Support tickets related to timeline issues |
| Extension revenue accuracy | 100% | Audit of extension charges vs timeline |
| Early start adoption | Track baseline | % of bookings with early starts |
| Customer satisfaction | No decrease | NPS score for timeline feature |

### 18.3 Monitoring Dashboard

**Key Dashboard Panels**:
1. **Timeline Recalculation Overview**
   - Success rate (line chart)
   - Total recalculations (counter)
   - Average early start minutes (gauge)

2. **Extension Analysis**
   - Extensions from recalculated vs scheduled (pie chart)
   - Extension revenue (line chart)
   - Average extension duration (gauge)

3. **Error Tracking**
   - Recalculation failures (line chart)
   - Validation errors (bar chart)
   - Extreme cases flagged (table)

4. **Performance**
   - API latency P50/P95/P99 (line chart)
   - Database query time (line chart)
   - Cache hit rate (gauge)

## 19. Compliance and Audit

### 19.1 Audit Trail

Every timeline modification is logged in `engagement_modifications` table:

```sql
INSERT INTO engagement_modifications (
  engagement_id,
  modification_type,
  modified_by,
  modified_at,
  details
) VALUES (
  12345,
  'TIMELINE_RECALCULATED',
  'SYSTEM',
  NOW(),
  jsonb_build_object(
    'scheduled_start_epoch', 1720101600,
    'actual_start_epoch', 1720099800,
    'scheduled_end_epoch', 1720105200,
    'actual_end_epoch', 1720103400,
    'early_start_minutes', 30,
    'duration_minutes', 60
  )
);
```

### 19.2 Data Retention

**Timeline Historical Data**:
- Scheduled times: Retained permanently
- Actual times: Retained permanently
- Modification logs: Retained for 7 years (compliance)
- Audit trail: Retained permanently

### 19.3 Dispute Resolution

In case of customer disputes regarding billing or timeline:
1. Query `engagement_modifications` for complete timeline history
2. Review `actual_start_epoch`, `actual_end_epoch`, and all extensions
3. Verify billing calculations match actual timeline
4. Provide transparent timeline breakdown to customer

## 20. Future Enhancements

### 20.1 Potential Features (Phase 2)

1. **Predictive Analytics**
   - ML model to predict early/late starts
   - Notify customers of likely timeline changes

2. **Dynamic Duration Adjustment**
   - Allow providers to extend duration mid-service
   - Automatic timeline recalculation

3. **Timeline Optimization**
   - Suggest optimal start times based on historical data
   - Reduce early starts through better scheduling

4. **Customer Notifications**
   - Real-time push notifications on timeline changes
   - SMS alerts for early starts

### 20.2 Technical Debt Considerations

- Migrate v1 API clients to v2 over 6 months
- Consolidate timeline calculation logic into single source of truth
- Implement GraphQL API for more flexible timeline queries
- Add WebSocket support for real-time timeline updates

---

**Document Version**: 1.0  
**Last Updated**: 2026-07-04  
**Authors**: Kiro AI Assistant  
**Reviewers**: [To be assigned]  
**Status**: Draft - Pending Review
