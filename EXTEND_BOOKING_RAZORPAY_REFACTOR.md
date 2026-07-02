# Extend Booking Razorpay Payment Flow Refactor

## Summary
Refactored the POST `/api/v2/engagements/:id/extend` endpoint to follow the two-step Razorpay payment flow pattern used in booking creation, separating payment initiation from verification.

## Changes Made

### 1. Added Required Imports
**File:** `services/payments/src/routes/v2/engagementsV2.js`

Added imports for Razorpay payment processing:
```javascript
import { razorpay, getRazorpayKeyId, getRazorpayKeySecret } from "../../utils/razorpayConfig.js";
import { createHmac } from "crypto";
```

### 2. Refactored POST `/api/v2/engagements/:id/extend`
**Purpose:** Initiate extension payment (Step 1)

**Flow:**
1. ✅ Validates extension request (hours, end time, amount)
2. ✅ Checks booking eligibility (ON_DEMAND, active status, provider assigned)
3. ✅ Checks for provider conflicts in the extended time slot
4. ✅ Creates Razorpay order using `razorpay.orders.create()`
5. ✅ Creates payment record with `PENDING` status and `razorpay_order_id`
6. ✅ Logs `EXTENSION_INITIATED` event with extension details in metadata
7. ✅ Returns payment info WITHOUT updating engagement or marking payment SUCCESS

**Request Body:**
```json
{
  "extensionHours": 2,
  "newEndTime": "2024-01-15T18:00:00",
  "additionalAmount": 500.00
}
```

**Response:**
```json
{
  "success": true,
  "requires_payment": true,
  "razorpay_order_id": "order_xyz123",
  "razorpay_key_id": "rzp_live_abc123",
  "amount": 50000,
  "currency": "INR",
  "extensionDetails": {
    "hours": 2,
    "additionalAmount": 500.00,
    "newEndTime": "2024-01-15T18:00:00",
    "oldEndEpoch": 1705329600,
    "newEndEpoch": 1705336800
  }
}
```

### 3. Created POST `/api/v2/engagements/:id/extend/verify`
**Purpose:** Verify payment and complete extension (Step 2)

**Flow:**
1. ✅ Verifies Razorpay signature (matches `/api/v2/createEngagements/verify` pattern)
2. ✅ Retrieves `EXTENSION_INITIATED` event to get extension details (newEndEpoch, extensionHours, etc.)
3. ✅ Updates engagement (`end_epoch`, `base_amount`)
4. ✅ Updates payment status to `SUCCESS` with `razorpay_payment_id`
5. ✅ Logs `BOOKING_EXTENDED` event
6. ✅ Sends notification to provider using `createInAppNotification()`
7. ✅ Returns success with updated engagement

**Request Body:**
```json
{
  "razorpay_order_id": "order_xyz123",
  "razorpay_payment_id": "pay_abc456",
  "razorpay_signature": "signature_hash"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Booking extended by 2 hours successfully",
  "engagement": { /* updated engagement object */ },
  "extensionDetails": {
    "hours": 2,
    "additionalAmount": 500.00,
    "newEndTime": "2024-01-15T18:00:00"
  }
}
```

## Key Features

### Security
- ✅ Razorpay signature verification (HMAC SHA256)
- ✅ Transaction locking with `FOR UPDATE` to prevent race conditions
- ✅ Conflict checks before payment initiation AND after payment verification

### Error Handling
- ✅ Proper ROLLBACK on errors at all stages
- ✅ Descriptive error messages for validation failures
- ✅ 409 Conflict status for provider time conflicts
- ✅ 404 Not Found for missing engagement or extension event

### Data Integrity
- ✅ Extension details stored in `EXTENSION_INITIATED` event
- ✅ Payment record with PENDING → SUCCESS lifecycle
- ✅ Event log for audit trail (`EXTENSION_INITIATED`, `BOOKING_EXTENDED`)
- ✅ Provider notification after successful extension

### Pattern Consistency
- ✅ Matches the flow used in `/api/v2/createEngagements` for booking creation
- ✅ Follows same signature verification pattern as `/api/v2/createEngagements/verify`
- ✅ Uses same payment record structure
- ✅ Consistent error handling and transaction management

## Database Schema Requirements

The refactor assumes these tables and columns exist:

### `engagements` table
- `engagement_id`, `booking_type`, `task_status`, `end_epoch`, `base_amount`
- `serviceproviderid`, `customerid`, `start_epoch`

### `payments` table
- `engagement_id`, `total_amount`, `base_amount`, `platform_fee`, `gst`
- `payment_mode`, `status`, `razorpay_order_id`, `transaction_id`
- `created_at`, `updated_at`

### `engagement_events` table
- `engagement_id`, `from_status`, `to_status`, `event_type`
- `actor_type`, `actor_id`, `metadata` (JSONB)
- `created_at`

## Frontend Integration

### Step 1: Call `/extend` endpoint
```javascript
const response = await fetch(`/api/v2/engagements/${id}/extend`, {
  method: 'POST',
  body: JSON.stringify({
    extensionHours: 2,
    newEndTime: '2024-01-15T18:00:00',
    additionalAmount: 500.00
  })
});

const { razorpay_order_id, razorpay_key_id, amount } = await response.json();
```

### Step 2: Open Razorpay Checkout
```javascript
const options = {
  key: razorpay_key_id,
  amount: amount,
  currency: "INR",
  name: "Booking Extension",
  order_id: razorpay_order_id,
  handler: async (razorpayResponse) => {
    // Step 3: Verify payment
    await verifyExtension(razorpayResponse);
  }
};

const razorpay = new Razorpay(options);
razorpay.open();
```

### Step 3: Call `/extend/verify` endpoint
```javascript
async function verifyExtension(razorpayResponse) {
  const response = await fetch(`/api/v2/engagements/${id}/extend/verify`, {
    method: 'POST',
    body: JSON.stringify({
      razorpay_order_id: razorpayResponse.razorpay_order_id,
      razorpay_payment_id: razorpayResponse.razorpay_payment_id,
      razorpay_signature: razorpayResponse.razorpay_signature
    })
  });

  const result = await response.json();
  // Show success message and update UI
}
```

## Testing Checklist

- [ ] Test extension initiation with valid data
- [ ] Test extension initiation with invalid hours
- [ ] Test extension with non-ON_DEMAND booking
- [ ] Test extension with inactive booking
- [ ] Test extension with provider conflicts
- [ ] Test payment verification with valid signature
- [ ] Test payment verification with invalid signature
- [ ] Test payment verification with missing EXTENSION_INITIATED event
- [ ] Verify engagement is updated after successful verification
- [ ] Verify payment status changes from PENDING to SUCCESS
- [ ] Verify provider receives notification
- [ ] Test concurrent extension attempts (race conditions)

## Migration Notes

**Breaking Change:** The `/extend` endpoint no longer directly updates the engagement or creates a SUCCESS payment. Frontend code must be updated to:

1. Call `/extend` to get Razorpay order details
2. Complete Razorpay payment in the frontend
3. Call `/extend/verify` with payment details to finalize extension

**Backward Compatibility:** None - this is a breaking change requiring frontend updates.

## Benefits

1. **Better payment tracking:** PENDING → SUCCESS lifecycle in payments table
2. **Audit trail:** Extension details preserved in engagement_events
3. **Security:** Razorpay signature verification prevents payment fraud
4. **Consistency:** Same pattern as booking creation flow
5. **Reliability:** Transaction locking prevents race conditions
6. **Observability:** Clear event log for debugging and monitoring

## Related Files

- `services/payments/src/routes/v2/engagementsV2.js` - Main implementation
- `services/payments/src/routes/v2/createEngagements.js` - Reference pattern
- `services/payments/src/utils/razorpayConfig.js` - Razorpay utilities
- `services/payments/src/services/inAppNotification.service.js` - Notifications

## Next Steps

1. Update frontend to use the new two-step flow
2. Test with Razorpay sandbox environment
3. Add unit tests for both endpoints
4. Update API documentation
5. Consider adding webhook support for automatic verification
