# Requirements Document

## Introduction

The Dynamic Booking Timeline Recalculation feature standardizes booking timelines based on actual service start times. Currently, when a Service Provider arrives early and starts service before the scheduled time, the system continues using the originally booked start time for calculating service end times and extension durations. This creates incorrect timelines, confusion, and billing inaccuracies across the platform.

This feature will capture the actual service start time when a booking enters In Progress status and recalculate the booking timeline while preserving the originally booked duration. All subsequent calculations for extensions and billing will use the recalculated timeline.

## Glossary

- **Booking_System**: The backend service that manages booking lifecycle, state transitions, and timeline calculations
- **Timeline_Calculator**: The component responsible for calculating booking start times, end times, and extension durations
- **Booking**: An engagement between a customer and service provider with defined start time, end time, and duration
- **Actual_Start_Time**: The timestamp when the service provider actually begins service delivery (captured when status transitions to In Progress)
- **Scheduled_Start_Time**: The originally booked start time agreed upon at booking creation
- **Booked_Duration**: The originally agreed-upon service duration in minutes (preserved after recalculation)
- **End_Time**: The calculated time when service should complete, based on start time plus booked duration
- **Extension**: An additional service duration added to an active booking beyond the original end time
- **In_Progress_Status**: The booking state indicating the service provider has started service delivery
- **Mobile_App**: The iOS or Android application used by customers and service providers
- **Web_App**: The web application used by customers to view and manage bookings
- **Booking_Summary**: The display component showing booking timeline details to users

## Requirements

### Requirement 1: Capture Actual Service Start Time

**User Story:** As a customer, I want the system to capture when my service provider actually starts the service, so that my booking timeline reflects reality.

#### Acceptance Criteria

1. WHEN a booking transitions to In_Progress_Status, THE Booking_System SHALL capture the Actual_Start_Time with precision to the second
2. THE Booking_System SHALL store the Actual_Start_Time in UTC format in the database
3. THE Booking_System SHALL preserve the Scheduled_Start_Time for historical records
4. IF the Actual_Start_Time is before the Scheduled_Start_Time, THEN THE Booking_System SHALL flag the booking as early-start
5. THE Booking_System SHALL record the Actual_Start_Time regardless of whether it occurs before, at, or after the Scheduled_Start_Time

### Requirement 2: Recalculate Booking End Time

**User Story:** As a customer, I want my booking end time to be calculated from when service actually started, so that extension calculations are accurate.

#### Acceptance Criteria

1. WHEN the Actual_Start_Time is captured, THE Timeline_Calculator SHALL recalculate the End_Time as Actual_Start_Time plus Booked_Duration
2. THE Timeline_Calculator SHALL preserve the Booked_Duration from the original booking without modification
3. IF the Actual_Start_Time is 30 minutes before Scheduled_Start_Time AND the Booked_Duration is 60 minutes, THEN THE End_Time SHALL be 30 minutes before the originally scheduled end time
4. THE Timeline_Calculator SHALL store the recalculated End_Time in the database
5. THE Timeline_Calculator SHALL maintain precision to the minute when calculating End_Time

### Requirement 3: Calculate Extensions from Recalculated Timeline

**User Story:** As a customer, I want my service extensions to be calculated from the updated end time, so that I pay for the correct duration.

#### Acceptance Criteria

1. WHEN a customer requests an extension, THE Timeline_Calculator SHALL calculate the new End_Time using the recalculated End_Time as the base
2. THE Timeline_Calculator SHALL add the extension duration in minutes to the current recalculated End_Time
3. IF the recalculated End_Time is 2:30 PM AND the customer extends by 60 minutes, THEN THE new End_Time SHALL be 3:30 PM
4. THE Timeline_Calculator SHALL NOT use the Scheduled_Start_Time or originally scheduled end time for extension calculations
5. THE Booking_System SHALL store each extension with its calculation base timestamp for audit purposes

### Requirement 4: Display Recalculated Timeline on Mobile Apps

**User Story:** As a customer using the mobile app, I want to see the updated booking timeline, so that I know when my service will end.

#### Acceptance Criteria

1. WHEN a booking has a recalculated timeline, THE Mobile_App SHALL display the Actual_Start_Time instead of Scheduled_Start_Time
2. THE Mobile_App SHALL display the recalculated End_Time in the active booking screen
3. THE Mobile_App SHALL display the recalculated End_Time in the Booking_Summary
4. THE Mobile_App SHALL indicate when the Actual_Start_Time differs from the Scheduled_Start_Time with a visual indicator
5. WHEN calculating time remaining, THE Mobile_App SHALL use the recalculated End_Time as the reference point

### Requirement 5: Display Recalculated Timeline on Web App

**User Story:** As a customer using the web app, I want to see the updated booking timeline, so that I have consistent information across platforms.

#### Acceptance Criteria

1. WHEN a booking has a recalculated timeline, THE Web_App SHALL display the Actual_Start_Time instead of Scheduled_Start_Time
2. THE Web_App SHALL display the recalculated End_Time in the booking details view
3. THE Web_App SHALL display the recalculated End_Time in the Booking_Summary
4. THE Web_App SHALL indicate when the Actual_Start_Time differs from the Scheduled_Start_Time with a visual indicator
5. THE Web_App SHALL synchronize timeline updates within 5 seconds of backend changes

### Requirement 6: Update Billing Calculations

**User Story:** As a customer, I want my billing to be based on the actual service time, so that I am charged correctly.

#### Acceptance Criteria

1. WHEN calculating billing for a booking, THE Booking_System SHALL use the Actual_Start_Time and recalculated End_Time
2. THE Booking_System SHALL calculate extension charges based on the recalculated End_Time
3. THE Booking_System SHALL generate billing records that reference both Scheduled_Start_Time and Actual_Start_Time for transparency
4. IF a booking includes extensions, THEN THE Booking_System SHALL itemize each extension with its start time and duration
5. THE Booking_System SHALL ensure billing precision to the minute for all time-based charges

### Requirement 7: Maintain Timeline Consistency Across Services

**User Story:** As a system administrator, I want timeline calculations to be consistent across all services, so that there are no data conflicts.

#### Acceptance Criteria

1. THE Booking_System SHALL apply timeline recalculation logic uniformly across all booking types (on-demand, short-term, monthly)
2. THE Booking_System SHALL apply timeline recalculation logic uniformly across all service types (cook, maid, nanny)
3. WHEN a timeline is recalculated, THE Booking_System SHALL broadcast the update to all dependent services within 2 seconds
4. THE Booking_System SHALL ensure atomic updates so that Actual_Start_Time and End_Time remain consistent
5. IF any service component queries booking timeline data, THEN THE Booking_System SHALL return the recalculated values when they exist

### Requirement 8: Handle Edge Cases and Validation

**User Story:** As a system administrator, I want the system to handle edge cases gracefully, so that timeline recalculation does not create data corruption.

#### Acceptance Criteria

1. IF the Actual_Start_Time is more than 2 hours before the Scheduled_Start_Time, THEN THE Booking_System SHALL log an alert and require manual review
2. IF the Actual_Start_Time is after the originally scheduled end time, THEN THE Booking_System SHALL log an alert and require manual review
3. WHEN validating Actual_Start_Time, THE Booking_System SHALL reject timestamps from the future
4. THE Booking_System SHALL prevent duplicate In_Progress_Status transitions that would overwrite Actual_Start_Time
5. IF timeline recalculation fails, THEN THE Booking_System SHALL fall back to Scheduled_Start_Time and log the failure

### Requirement 9: Preserve Historical Data and Audit Trail

**User Story:** As a system administrator, I want to maintain historical booking data, so that we can analyze service patterns and resolve disputes.

#### Acceptance Criteria

1. THE Booking_System SHALL store both Scheduled_Start_Time and Actual_Start_Time permanently
2. THE Booking_System SHALL record a timeline recalculation event in the booking modification history
3. THE Booking_System SHALL include the delta between Scheduled_Start_Time and Actual_Start_Time in the modification record
4. THE Booking_System SHALL maintain immutable records of all End_Time changes with timestamps
5. THE Booking_System SHALL retain the original scheduled end time alongside the recalculated End_Time for reporting purposes

### Requirement 10: API Response Format

**User Story:** As a frontend developer, I want consistent API response formats, so that I can display timeline data without complex logic.

#### Acceptance Criteria

1. WHEN returning booking data, THE Booking_System SHALL include both scheduled_start_time and actual_start_time fields
2. WHEN returning booking data, THE Booking_System SHALL include both scheduled_end_time and end_time fields
3. THE Booking_System SHALL include an is_timeline_recalculated boolean field indicating whether recalculation has occurred
4. THE Booking_System SHALL include an early_start_minutes field showing the difference when service starts early
5. WHEN actual_start_time is null, THE frontend applications SHALL display scheduled_start_time as the start time
