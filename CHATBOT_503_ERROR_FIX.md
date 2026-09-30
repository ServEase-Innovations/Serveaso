# Chatbot 503 Error Fix - iOS App

## Issue
When clicking "Live Support" in the chatbot, users encountered a 503 Service Unavailable error:
```
AxiosError: Request failed with status code 503
url = "https://chat-b3wl.onrender.com/api/user/find-or-create"
reason = "service unavailable"
```

### Root Cause
The chatbot service is hosted on Render's free tier, which automatically spins down after periods of inactivity. When a user tries to access the service while it's asleep, it takes approximately 50 seconds to wake up, causing the initial request to fail with a 503 error.

## Solution
Added intelligent error handling with:
1. **Extended timeout** (60 seconds) to accommodate service wake-up time
2. **503-specific error detection** and user-friendly messaging
3. **Automatic retry option** with guided user experience
4. **Better error context** explaining the delay

### Changes Made

#### `/apps/servease-ios/src/Chatbot/Chatbot.tsx`

**1. Extended Request Timeout:**
```typescript
axios.post(
  `${ENDPOINT}/api/user/find-or-create`,
  { name: appUser.name, email: appUser.email },
  { timeout: 60000 } // 60 second timeout for service wake-up
);
```

**2. 503-Specific Error Handling:**
```typescript
catch (err: any) {
  if (err.response?.status === 503 || err.code === 'ECONNABORTED') {
    // Show user-friendly message about service starting
    Alert.alert(
      'Service Starting',
      'Our chat service is waking up (this takes about 50 seconds on first use). Please try again in a moment.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Retry',
          onPress: () => {
            setStartingChat(false);
            setTimeout(() => startLiveChat(), 2000);
          },
        },
      ]
    );
  } else {
    // Generic error for other issues
    Alert.alert('Error', 'Failed to start live chat. Please try again later.');
  }
}
```

## User Experience Improvements

### Before (Bad UX):
1. User clicks "Live Support"
2. Gets generic error: "Failed to start live chat. Please try again."
3. User is confused - no explanation of why it failed
4. User may give up or think the feature is broken

### After (Good UX):
1. User clicks "Live Support"
2. If service is asleep, gets clear message:
   - **Title**: "Service Starting"
   - **Message**: "Our chat service is waking up (this takes about 50 seconds on first use). Please try again in a moment."
   - **Options**: 
     - "Cancel" - user can dismiss
     - "Retry" - automatically retries after 2 seconds
3. User understands the delay and can easily retry
4. On retry, service is usually awake and connects successfully

## Technical Details

### Error Detection
The fix detects two scenarios:
1. **503 Status Code**: `err.response?.status === 503`
   - Service is starting up or unavailable
2. **Timeout Error**: `err.code === 'ECONNABORTED'`
   - Request exceeded 60-second timeout

### Retry Mechanism
- **Delay**: 2 seconds before automatic retry
- **Reset State**: `setStartingChat(false)` allows retry
- **User Control**: User can cancel or retry manually

### Timeout Strategy
- **Default**: Most requests have short timeouts (10-30 seconds)
- **Chat Service**: 60 seconds to accommodate cold start
- **Rationale**: Render free tier can take 30-50 seconds to wake up

## Alternative Solutions Considered

### 1. Automatic Background Ping (Rejected)
- **Idea**: Ping chat service periodically to keep it awake
- **Why Rejected**: 
  - Wastes resources
  - Doesn't help if user hasn't used app recently
  - Violates Render free tier fair use

### 2. Migration to Always-On Service (Future)
- **Idea**: Move to paid Render tier or different provider
- **Status**: Viable for production, but not immediate fix
- **Cost**: $7-25/month for always-on service

### 3. Exponential Backoff Retry (Rejected)
- **Idea**: Automatic retry with increasing delays
- **Why Rejected**:
  - User loses control
  - May frustrate users waiting
  - Current manual retry with clear messaging is better UX

## Testing Recommendations

1. **Cold Start Test**:
   - Wait 15+ minutes for service to sleep
   - Click "Live Support"
   - Verify friendly 503 message appears
   - Click "Retry" after 50 seconds
   - Verify connection succeeds

2. **Hot Start Test**:
   - Use chat service
   - Wait < 5 minutes
   - Click "Live Support" again
   - Verify immediate connection (no 503)

3. **Network Error Test**:
   - Turn off WiFi
   - Click "Live Support"
   - Verify generic error message (not 503 message)

4. **Retry Flow Test**:
   - Trigger 503 error
   - Click "Retry" button
   - Verify retry happens after 2 seconds
   - Verify connection succeeds after wake-up

## Monitoring

### Sentry Integration
The fix preserves Sentry error logging:
- 503 errors are still logged with full context
- Retry attempts are tracked
- Success/failure rates can be monitored

### Key Metrics to Track
- **503 Error Rate**: % of chat initiations that get 503
- **Retry Success Rate**: % of retries that succeed
- **Average Wake-Up Time**: Time from 503 to successful connection
- **User Abandonment**: % of users who cancel vs retry

## Production Deployment Notes

### Immediate (Current Fix):
- ✅ Better user experience with clear messaging
- ✅ Guided retry flow
- ✅ Works with free tier service

### Future Enhancement:
- Consider upgrading to paid Render tier ($7/mo) for instant connections
- Or migrate to AWS Lambda with provisioned concurrency
- Add health check endpoint to monitor service status

## Files Modified

1. `apps/servease-ios/src/Chatbot/Chatbot.tsx` - Enhanced error handling

## Impact

- ✅ **Better UX**: Clear communication about service state
- ✅ **Higher Success Rate**: Guided retry increases connection success
- ✅ **Reduced Confusion**: Users understand why delay occurs
- ✅ **Maintained Free Tier**: No additional costs
- ✅ **Professional Feel**: Transparent about infrastructure limitations

## Next Steps

1. Test the retry flow thoroughly
2. Monitor 503 error rates in Sentry
3. Gather user feedback on messaging
4. Consider paid tier upgrade based on usage metrics
