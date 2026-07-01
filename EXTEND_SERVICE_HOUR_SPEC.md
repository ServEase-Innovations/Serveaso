# Extend Service Hour Feature - Implementation Specification

## Overview
Add an "Extend Service Hour" button for one-time (on-demand) bookings that allows users to extend their booking if the assigned provider has availability beyond the current booking end time.

## Requirements

### Functional Requirements
1. **Button Visibility**
   - Show "Extend Service Hour" button ONLY for:
     - One-time/On-demand bookings (`booking_type === 'ON_DEMAND'`)
     - Bookings with assigned providers
     - Active bookings (NOT_STARTED or IN_PROGRESS status)
     - When provider has availability after booking end time

2. **Provider Availability Check**
   - Check provider's availability after current booking end time
   - Determine maximum extendable hours based on provider schedule
   - Return available time slots for extension

3. **Extension Options**
   - Show extension options based on available hours (1, 2, 3, etc.)
   - Each extension option should show:
     - Additional hours
     - Additional cost
     - New end time
   - Limit to provider's continuous availability

4. **User Flow**
   - User clicks "Extend Service Hour" button
   - System checks provider availability
   - Show dialog with extension options
   - User selects desired extension hours
   - Show confirmation with pricing
   - Process payment (if applicable)
   - Update booking end time and amount

### Non-Functional Requirements
- Fast availability check (< 2 seconds)
- Real-time price calculation
- Secure payment processing
- Optimistic UI updates

## Technical Design

### 1. API Endpoints

#### Check Provider Availability for Extension
```
GET /api/v2/engagements/:engagementId/extension-availability
```

**Response:**
```json
{
  "success": true,
  "canExtend": true,
  "maxExtensionHours": 3,
  "providerAvailable": true,
  "currentEndTime": "2025-01-20T14:00:00Z",
  "availableSlots": [
    {
      "hours": 1,
      "newEndTime": "2025-01-20T15:00:00Z",
      "additionalCost": 200
    },
    {
      "hours": 2,
      "newEndTime": "2025-01-20T16:00:00Z",
      "additionalCost": 400
    },
    {
      "hours": 3,
      "newEndTime": "2025-01-20T17:00:00Z",
      "additionalCost": 600
    }
  ]
}
```

#### Extend Booking
```
POST /api/v2/engagements/:engagementId/extend
```

**Request:**
```json
{
  "extensionHours": 2,
  "newEndTime": "2025-01-20T16:00:00Z",
  "additionalAmount": 400,
  "paymentMode": "RAZORPAY"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Booking extended successfully",
  "engagement": {
    "engagement_id": 123,
    "end_time": "2025-01-20T16:00:00Z",
    "end_epoch": 1705762800,
    "total_amount": 1400,
    "extension_count": 1
  },
  "payment": {
    "payment_id": 456,
    "amount": 400,
    "status": "SUCCESS"
  }
}
```

### 2. Frontend Components

#### Component Structure
```
EngagementDetailsDrawer
  └── ExtendServiceHourButton (conditional)
       └── ExtendServiceHourDialog
            ├── AvailabilityLoader
            ├── ExtensionOptions
            ├── PriceBreakdown
            └── ConfirmButton
```

#### State Management
```typescript
const [showExtendDialog, setShowExtendDialog] = useState(false);
const [extensionAvailability, setExtensionAvailability] = useState(null);
const [loadingAvailability, setLoadingAvailability] = useState(false);
const [selectedExtension, setSelectedExtension] = useState(null);
const [isExtending, setIsExtending] = useState(false);
```

### 3. Business Logic

#### Visibility Logic
```typescript
const canShowExtendButton = () => {
  return (
    booking.bookingType === 'ON_DEMAND' &&
    booking.serviceProviderId &&
    ['NOT_STARTED', 'IN_PROGRESS'].includes(booking.taskStatus) &&
    !isBookingEnded() &&
    isProviderAssigned()
  );
};
```

#### Availability Check Logic
```typescript
const checkExtensionAvailability = async () => {
  try {
    setLoadingAvailability(true);
    const response = await PaymentInstance.get(
      `/api/v2/engagements/${booking.id}/extension-availability`
    );
    setExtensionAvailability(response.data);
  } catch (error) {
    console.error('Error checking availability:', error);
    Alert.alert('Error', 'Unable to check availability');
  } finally {
    setLoadingAvailability(false);
  }
};
```

#### Extension Logic
```typescript
const handleExtendBooking = async (extensionOption) => {
  try {
    setIsExtending(true);
    const response = await PaymentInstance.post(
      `/api/v2/engagements/${booking.id}/extend`,
      {
        extensionHours: extensionOption.hours,
        newEndTime: extensionOption.newEndTime,
        additionalAmount: extensionOption.additionalCost,
      }
    );
    
    // Update local state
    setBooking(response.data.engagement);
    
    Alert.alert('Success', 'Booking extended successfully');
    setShowExtendDialog(false);
    refreshBookings?.();
  } catch (error) {
    const message = error.response?.data?.error || 'Failed to extend booking';
    Alert.alert('Error', message);
  } finally {
    setIsExtending(false);
  }
};
```

### 4. UI/UX Design

#### Button Design
```tsx
<TouchableOpacity
  style={[styles.extendButton, { borderColor: colors.accent }]}
  onPress={handleExtendClick}
>
  <Icon name="clock-plus-outline" size={16} color={colors.accent} />
  <Text style={[styles.extendButtonText, { color: colors.accent }]}>
    Extend Service Hour
  </Text>
</TouchableOpacity>
```

#### Dialog Design
- Modal with bottom sheet animation
- Loading state while checking availability
- Radio buttons for extension options
- Price breakdown section
- Confirm and Cancel buttons

### 5. Backend Implementation

#### Availability Check Logic
```javascript
async function checkExtensionAvailability(engagementId) {
  const engagement = await getEngagement(engagementId);
  const provider = await getProvider(engagement.serviceProviderId);
  const currentEndEpoch = engagement.end_epoch;
  
  // Check provider's availability after current end time
  const providerSchedule = await getProviderSchedule(
    provider.id,
    currentEndEpoch
  );
  
  // Check for conflicts with other bookings
  const conflicts = await checkProviderConflicts(
    provider.id,
    currentEndEpoch,
    currentEndEpoch + (4 * 3600) // Check up to 4 hours
  );
  
  // Calculate max continuous availability
  const maxHours = calculateMaxExtension(
    providerSchedule,
    conflicts,
    currentEndEpoch
  );
  
  // Generate extension options
  const slots = [];
  for (let i = 1; i <= maxHours; i++) {
    slots.push({
      hours: i,
      newEndTime: new Date((currentEndEpoch + i * 3600) * 1000),
      additionalCost: engagement.hourly_rate * i
    });
  }
  
  return {
    canExtend: maxHours > 0,
    maxExtensionHours: maxHours,
    availableSlots: slots
  };
}
```

#### Extension Logic
```javascript
async function extendBooking(engagementId, extensionData) {
  const engagement = await getEngagement(engagementId);
  
  // Validate extension request
  validateExtension(engagement, extensionData);
  
  // Check availability again (prevent race conditions)
  const availability = await checkExtensionAvailability(engagementId);
  if (!availability.canExtend) {
    throw new Error('Provider no longer available');
  }
  
  // Process payment
  const payment = await processExtensionPayment(
    engagement,
    extensionData.additionalAmount
  );
  
  // Update engagement
  await updateEngagement(engagementId, {
    end_time: extensionData.newEndTime,
    end_epoch: dateToEpoch(extensionData.newEndTime),
    total_amount: engagement.total_amount + extensionData.additionalAmount,
    extension_count: (engagement.extension_count || 0) + 1,
    last_extended_at: new Date()
  });
  
  // Log extension event
  await logEngagementEvent(engagementId, {
    event_type: 'BOOKING_EXTENDED',
    metadata: {
      extension_hours: extensionData.extensionHours,
      additional_amount: extensionData.additionalAmount,
      new_end_time: extensionData.newEndTime
    }
  });
  
  // Notify provider
  await notifyProvider(engagement.serviceProviderId, {
    type: 'BOOKING_EXTENDED',
    engagementId,
    extensionHours: extensionData.extensionHours
  });
  
  return { engagement, payment };
}
```

## Database Schema Changes

### engagements table
```sql
ALTER TABLE engagements
ADD COLUMN extension_count INT DEFAULT 0,
ADD COLUMN last_extended_at TIMESTAMP,
ADD COLUMN original_end_epoch INT;
```

### engagement_events table
```sql
-- New event type: BOOKING_EXTENDED
-- Metadata should include:
-- - extension_hours
-- - additional_amount
-- - new_end_time
-- - old_end_time
```

## Testing Checklist

### Unit Tests
- [ ] Availability check logic
- [ ] Extension validation
- [ ] Price calculation
- [ ] Conflict detection

### Integration Tests
- [ ] API endpoint tests
- [ ] Payment processing
- [ ] Database updates
- [ ] Notifications

### E2E Tests
- [ ] Button visibility conditions
- [ ] Extension flow (happy path)
- [ ] Error scenarios
- [ ] Payment failures
- [ ] Provider conflicts

### Manual Testing
- [ ] UI/UX on different screen sizes
- [ ] Loading states
- [ ] Error messages
- [ ] Success messages
- [ ] Booking updates in real-time

## Edge Cases

1. **Provider becomes unavailable** - Show error when clicking extend
2. **Another booking created** - Conflict detection before payment
3. **Network failure** - Retry mechanism
4. **Payment failure** - Rollback and clear error state
5. **Multiple extensions** - Track extension count, set limits
6. **Booking ends during extension** - Validate booking is still active
7. **Provider cancels availability** - Real-time update

## Security Considerations

1. **Authorization** - Only booking owner can extend
2. **Rate limiting** - Prevent spam clicks
3. **Price validation** - Server-side price calculation
4. **Idempotency** - Prevent duplicate extensions
5. **Audit trail** - Log all extension attempts

## Performance Considerations

1. **Cache provider schedules** - Reduce DB queries
2. **Optimistic updates** - Show UI feedback immediately
3. **Background availability check** - Don't block UI
4. **Debounce API calls** - Prevent multiple requests

## Rollout Plan

### Phase 1: Backend Development
- [ ] Create API endpoints
- [ ] Implement availability logic
- [ ] Add database columns
- [ ] Write unit tests

### Phase 2: Frontend Development
- [ ] Add button to UI
- [ ] Create extension dialog
- [ ] Implement state management
- [ ] Add loading/error states

### Phase 3: Testing
- [ ] QA testing
- [ ] User acceptance testing
- [ ] Load testing

### Phase 4: Deployment
- [ ] Deploy to staging
- [ ] Monitor logs
- [ ] Deploy to production
- [ ] Enable feature flag

## Success Metrics

- Extension button click rate
- Successful extension rate
- Average extension hours
- Revenue from extensions
- User satisfaction (feedback)
- Provider acceptance rate

## Future Enhancements

1. **Auto-extend suggestion** - Suggest extension before booking ends
2. **Discount for extensions** - Incentivize longer bookings
3. **Bulk extension** - Extend multiple bookings at once
4. **Extension history** - Show past extensions
5. **Provider preferences** - Let providers set extension rules

---
**Status**: Specification Complete  
**Priority**: High  
**Complexity**: Medium-High  
**Estimated Effort**: 2-3 days  
**Date**: January 2025
