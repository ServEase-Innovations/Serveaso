# Slot Selection Overlap Fix - iOS App

## Issue
When users added 2 custom time slots and then selected the Morning, Afternoon, or Evening preset options from the upper section, the application incorrectly displayed 5 total slots instead of preventing overlapping slots.

### Root Cause
The `applyPreset` function in `AvailabilityPicker.tsx` was only checking for exact duplicate slots (same start and end times) but not checking for overlapping time ranges. This meant:
- Adding 2 custom slots (e.g., 9 AM - 11 AM, 2 PM - 4 PM)
- Then clicking "Morning" (6 AM - 12 PM) would add it even though it overlaps with the first slot
- Clicking "Afternoon" (12 PM - 4 PM) would add it even though it overlaps with the second slot
- Clicking "Evening" (4 PM - 8 PM) would add it
- Result: 2 + 3 = 5 slots displayed

## Solution
Added overlap detection to prevent adding preset time slots that overlap with existing custom slots.

### Changes Made

#### 1. `/apps/servease-ios/src/common/AvailabilityPicker/availabilityUtils.ts`
- **Added `isOverlappingSlot` function** to detect when a candidate slot overlaps with any existing slot
- Overlap is detected when:
  - Candidate starts within an existing slot
  - Candidate ends within an existing slot
  - Candidate completely contains an existing slot

```typescript
export function isOverlappingSlot(
  slots: AvailabilitySlot[],
  candidate: AvailabilitySlot
): boolean {
  return slots.some(
    (slot) =>
      slot.id !== candidate.id &&
      ((candidate.startMinutes >= slot.startMinutes && candidate.startMinutes < slot.endMinutes) ||
       (candidate.endMinutes > slot.startMinutes && candidate.endMinutes <= slot.endMinutes) ||
       (candidate.startMinutes <= slot.startMinutes && candidate.endMinutes >= slot.endMinutes))
  );
}
```

#### 2. `/apps/servease-ios/src/common/AvailabilityPicker/AvailabilityPicker.tsx`
- **Imported `isOverlappingSlot`** utility function
- **Added `showOverlapWarning` state** to track overlap conflicts
- **Updated `applyPreset` function** to check for overlaps before adding preset slots
- **Updated warning messages** to show appropriate error based on conflict type:
  - "This time slot is already added" for exact duplicates
  - "This time slot overlaps with an existing slot" for overlapping ranges
- **Updated state reset logic** in `switchMode`, `removeSlot`, and `updateSlot` to clear both warnings

### User Experience
**Before:**
1. Add 2 custom slots
2. Click Morning, Afternoon, Evening
3. See 5 slots total (incorrect)

**After:**
1. Add 2 custom slots
2. Click Morning → Shows "This time slot overlaps with an existing slot" (if it overlaps)
3. Click Afternoon → Shows overlap warning (if it overlaps)
4. Click Evening → Adds successfully (if no overlap)
5. Total slots shown = actual non-overlapping slots only

## Testing Recommendations
1. **Test Case 1**: Add custom slot 9 AM - 11 AM, then click "Morning" preset → Should show overlap warning
2. **Test Case 2**: Add custom slot 2 PM - 4 PM, then click "Afternoon" preset → Should show overlap warning
3. **Test Case 3**: Add custom slot 6 AM - 8 AM, then click "Evening" preset → Should add successfully (no overlap)
4. **Test Case 4**: Add custom slot 9 AM - 5 PM, then click any preset → Should show overlap warning for Morning, Afternoon, and Evening
5. **Test Case 5**: Add Morning preset, try to add it again → Should show duplicate warning

## Impact
- ✅ Prevents confusing UI where overlapping slots are shown
- ✅ Provides clear feedback to users about why a preset cannot be added
- ✅ Maintains data integrity by preventing overlapping time slots
- ✅ Works on both iOS and Android (shared component)

## Files Modified
1. `apps/servease-ios/src/common/AvailabilityPicker/availabilityUtils.ts`
2. `apps/servease-ios/src/common/AvailabilityPicker/AvailabilityPicker.tsx`

## Next Steps
1. Test on both iOS and Android devices
2. Push changes to servease-ios submodule
3. Update monorepo reference
