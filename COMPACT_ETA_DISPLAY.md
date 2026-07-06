# Compact ETA Display on Booking Cards

## Overview

Added a compact ETA display that shows on the "Today's Bookings" page, giving customers a quick view of when their provider will arrive **before** they even click "Track Provider".

---

## What It Looks Like

### On Today's Bookings Page

```
┌─────────────────────────────────────────────────────┐
│ 10:00 AM – 12:00 PM  [🕐 5 min · 📍 2.5 km 📈]     │
│ House Cleaning                                       │
│ #353 · John Smith                                    │
│                                                      │
│ [Track Provider] [Call] [Map] [View booking]        │
└─────────────────────────────────────────────────────┘
```

The compact ETA badge shows:
- **🕐 5 min** - Time until provider arrives (live countdown)
- **📍 2.5 km** - Distance between provider and service location
- **📈** - Live traffic indicator (only shown if traffic data available)

---

## When Does It Show?

The compact ETA display appears when:
1. ✅ Booking is in "UPCOMING" phase (not in progress or completed)
2. ✅ Provider is assigned (not awaiting provider)
3. ✅ Provider has started journey (published GPS location)
4. ✅ ETA calculation is available

**It does NOT show when:**
- ❌ Provider hasn't started journey yet
- ❌ Booking is "In Progress" or "Completed"
- ❌ Provider is unassigned
- ❌ ETA calculation failed

---

## Features

### Live Countdown
- Updates every second
- Shows time remaining until arrival
- Changes to "Arriving" when < 1 minute

### Color Coding
- **Green** (< 3 min): Provider arriving very soon
- **Blue** (3-10 min): Provider on the way
- **Amber** (> 10 min): Provider en route

### Auto-Refresh
- Automatically fetches ETA when card loads
- No manual refresh needed
- Silent failure if ETA not available

### Minimal Design
- Compact badge format
- Doesn't clutter the UI
- Shows key information only

---

## Technical Implementation

### Component Structure

```
CustomerTodayTasksCard.tsx
  └─> CompactETADisplay.tsx
        └─> calculateETA() from trackingService
```

### New File Created

**`CompactETADisplay.tsx`**
- Compact ETA component for booking cards
- Auto-fetches ETA on mount
- Live countdown timer
- Silent error handling
- Responsive design

### Modified Files

**`CustomerTodayTasksCard.tsx`**
- Added import for `CompactETADisplay`
- Integrated component next to scheduled time
- Only shows for upcoming bookings with assigned provider

---

## User Experience Flow

### Scenario 1: Provider En Route

```
1. Customer opens "Today's Bookings" page
2. Sees booking with scheduled time: "10:00 AM - 12:00 PM"
3. Compact ETA appears: "🕐 5 min · 📍 2.5 km 📈"
4. Countdown updates every second: "4 min... 3 min... 2 min..."
5. Customer knows provider is close without opening map
6. Can click "Track Provider" for full map view when desired
```

### Scenario 2: Provider Not Started

```
1. Customer opens "Today's Bookings" page
2. Sees booking with scheduled time: "10:00 AM - 12:00 PM"
3. No ETA badge shows (provider hasn't started journey)
4. Helper text shows: "Waiting for provider to start at 10:00 AM"
5. Once provider starts, ETA badge appears automatically
```

---

## Benefits

1. **At-a-Glance Information**: See ETA without opening map
2. **Proactive Updates**: Know when provider is close
3. **Reduces Anxiety**: Customers know provider is on the way
4. **Less Support Calls**: Clear visibility into arrival time
5. **Non-Intrusive**: Only shows when relevant

---

## Data Flow

```
1. Component mounts
   ↓
2. Calls calculateETA(engagementId)
   ↓
3. Backend checks:
   - Provider location available?
   - Engagement coordinates available?
   ↓
4. If yes: Calculate ETA with Google Maps
   ↓
5. Return ETA data
   ↓
6. Component displays badge
   ↓
7. Countdown updates every 1 second locally
```

---

## Code Example

### Usage in Booking Card

```tsx
import { CompactETADisplay } from '../Tracking/CompactETADisplay';

// In booking card component
{phase === "UPCOMING" && !unassigned && providerId && (
  <CompactETADisplay 
    engagementId={engagement.id}
  />
)}
```

### Component Props

```typescript
interface CompactETADisplayProps {
  engagementId: number;     // Required: The engagement to show ETA for
  onError?: (error: string) => void;  // Optional: Error callback
}
```

---

## Error Handling

### Silent Failures
The component handles errors gracefully:

1. **404 (Provider not started)**: Silently doesn't show
2. **400 (No coordinates)**: Silently doesn't show
3. **500 (API error)**: Silently doesn't show, optional error callback

**Why silent failures?**
- Not showing ETA is better than showing error messages
- Doesn't clutter the UI with error states
- Provider might just be preparing to start

---

## Performance

### Optimization Strategies

1. **Fetch on Mount Only**: No polling on booking list
   - Why: Too many requests if showing 10+ bookings
   - ETA is calculated once when page loads
   - Countdown runs locally without API calls

2. **Silent Failures**: No loading spinners
   - Component either shows or doesn't
   - No intermediate loading states
   - Cleaner UI experience

3. **Conditional Rendering**: Only fetches when conditions met
   - Checks phase, provider assignment first
   - Avoids unnecessary API calls

---

## API Usage

### Per Booking Card View

- **1 ETA calculation** when page loads (per upcoming booking)
- **0 subsequent calls** (countdown runs locally)

### Example: 3 Upcoming Bookings

- Page load: 3 ETA calculations
- Per minute: 0 additional calls
- Much more efficient than polling!

---

## Testing Scenarios

### Test 1: Provider En Route

```bash
# 1. Provider starts journey
curl -X POST .../api/tracking/provider/start-journey \
  -d '{"engagement_id": 353, "provider_id": 123}'

# 2. Provider publishes location
curl -X POST .../api/tracking/provider/location \
  -d '{"engagement_id": 353, "provider_id": 123, "latitude": 12.9, "longitude": 77.5}'

# 3. Open "Today's Bookings" page
# Expected: ETA badge appears next to scheduled time
```

### Test 2: Provider Not Started

```bash
# 1. Open "Today's Bookings" page
# Expected: No ETA badge shown
# Expected: Helper text says "Waiting for provider to start..."

# 2. Provider starts journey
curl -X POST .../api/tracking/provider/start-journey \
  -d '{"engagement_id": 353, "provider_id": 123}'

# 3. Refresh page
# Expected: ETA badge now appears
```

### Test 3: Multiple Bookings

```bash
# Have 3 bookings today:
# - Booking A: Provider en route (should show ETA)
# - Booking B: Provider not started (no ETA)
# - Booking C: Completed (no ETA, in different tab)

# Expected: Only Booking A shows ETA badge
```

---

## Design Specifications

### Badge Appearance

**Size**: Extra small (xs)
**Height**: 28px (1-line)
**Padding**: 8px horizontal, 4px vertical
**Border**: 1px solid
**Border Radius**: 6px (rounded-md)

### Colors

**Green Badge** (< 3 min):
- Background: `bg-green-50`
- Text: `text-green-700`
- Border: `border-green-200`

**Blue Badge** (3-10 min):
- Background: `bg-blue-50`
- Text: `text-blue-700`
- Border: `border-blue-200`

**Amber Badge** (> 10 min):
- Background: `bg-amber-50`
- Text: `text-amber-700`
- Border: `border-amber-200`

### Icons

- Clock: `lucide-react/Clock` (12px)
- Navigation: `lucide-react/Navigation` (12px)
- Traffic: `lucide-react/TrendingUp` (12px)

---

## Future Enhancements (Optional)

1. **Auto-Update**: Refresh ETA every 30 seconds
2. **Notifications**: Alert when provider is 5 min away
3. **Sound Alert**: Play sound when arriving soon
4. **Vibrate**: Mobile vibration on arrival
5. **ETA History**: Show accuracy over time

---

## Integration with Track Provider Button

### How They Work Together

**Compact ETA Display**:
- Shows quick summary on booking card
- No interaction required
- Auto-updates countdown

**Track Provider Button**:
- Opens full map view
- Shows detailed route
- Live tracking with updates
- All features available

**User Flow**:
```
1. See ETA badge: "5 min away"
2. Decide if want more details
3. Click "Track Provider" for full map
4. See route, exact location, etc.
```

Both features complement each other!

---

## Files Modified/Created

### New Files
- ✅ `apps/servase-ui/src/components/Tracking/CompactETADisplay.tsx`

### Modified Files
- ✅ `apps/servase-ui/src/components/User-Profile/CustomerTodayTasksCard.tsx`

### Documentation
- ✅ `COMPACT_ETA_DISPLAY.md` (this file)

---

## Summary

The compact ETA display provides at-a-glance arrival information on booking cards, making it easy for customers to see when their provider will arrive without opening the full tracking map. It's minimal, efficient, and enhances the user experience significantly.

**Key Points**:
- ✅ Shows ETA + distance next to scheduled time
- ✅ Live countdown updates every second
- ✅ Color-coded for quick understanding
- ✅ Only shows when provider is en route
- ✅ Silent failures (no error UI)
- ✅ Works alongside Track Provider button

---

**Status**: ✅ Complete and Ready
**Version**: 1.0
**Date**: July 6, 2026
