# iOS Email Validation API Fix

## Issue
Email validation during service provider registration was failing with 500 error:
```
Error validating email: AxiosError: Request failed with status code 500
```

## Root Cause
The iOS app was calling the **utils service** for email validation:
```
GET https://utils-j7bu.onrender.com/customer/check-email?email={email}
```

This endpoint was returning 500 errors due to database connection issues on the utils service.

## Solution
Changed email validation to use the **providers service** instead:
```
POST https://providers-35ix.onrender.com/api/service-providers/check-email
Body: { "email": "user@example.com" }
```

### Why This Works
- ✅ Providers service is healthy and working
- ✅ Same endpoint already used for mobile validation
- ✅ Consistent API usage (all validation on providers service)
- ✅ Returns the same response format: `{ "exists": true/false }`

## Changes Made

### File: `apps/servease-ios/src/Registration/useFieldValidation.tsx`

**Before:**
```typescript
if (fieldType === "email") {
  const { data } = await utilsInstance.get(
    `/customer/check-email?email=${encodeURIComponent(trimmed.toLowerCase())}`
  );
  const taken = Boolean(data?.exists);
```

**After:**
```typescript
if (fieldType === "email") {
  const { data } = await providerInstance.post(
    "/api/service-providers/check-email",
    { email: trimmed.toLowerCase() }
  );
  const taken = Boolean(data?.exists);
```

### What Didn't Change
**Auth0 Post-Login** still uses utils service because it needs full user profile data (role, service_provider_id, etc.), not just existence check.

File: `apps/servease-ios/src/services/auth0PostLogin.ts` - **No changes**

## API Comparison

### Email Validation APIs

| Use Case | Service | Endpoint | Method | Response |
|----------|---------|----------|--------|----------|
| **Registration validation** (NEW) | Providers | `/api/service-providers/check-email` | POST | `{exists: boolean}` |
| Post-login role detection | Utils | `/customer/check-email` | GET | `{exists, user_role, id, ...}` |

### Mobile Validation API (unchanged)
| Use Case | Service | Endpoint | Method | Response |
|----------|---------|----------|--------|----------|
| Registration validation | Providers | `/api/service-providers/check-mobile` | POST | `{exists: boolean}` |

## Testing

### Test Email Validation Endpoint
```bash
curl -X POST "https://providers-35ix.onrender.com/api/service-providers/check-email" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'

# Response: {"exists":false}
```

### Test in iOS App
1. Open the app
2. Go to Service Provider Registration
3. Enter an email address
4. Should see validation happening (loading spinner → checkmark or error)
5. No more 500 errors!

## Benefits

✅ **Fixed immediate issue** - Email validation now works  
✅ **More reliable** - Providers service is stable  
✅ **Consistent** - All validation (email + mobile) now on same service  
✅ **Cleaner architecture** - Registration uses providers API  
✅ **No utils dependency** - Registration doesn't need utils service  

## Environment

Email validation now uses:
- **Service**: Providers
- **URL**: From `.env.development`: `REACT_APP_PROVIDER_URL=https://providers-35ix.onrender.com`
- **Instance**: `providerInstance` (already used for mobile validation)

## Impact

- ✅ Service provider registration email validation works
- ✅ Agent registration email validation works (uses same hook)
- ✅ Customer registration email validation works
- ✅ Auth0 login flow unaffected (still uses utils for full profile)
- ✅ No changes to mobile validation

## Files Modified
- `apps/servease-ios/src/Registration/useFieldValidation.tsx` - Changed email validation API

## Files Unchanged
- `apps/servease-ios/src/services/auth0PostLogin.ts` - Still uses utils (needs full profile)

## Deployment Notes

After this change:
1. Users will see successful email validation in registration
2. No dependency on utils service for registration flow
3. Utils service can be fixed independently without blocking registration

## Future Improvements

Consider consolidating all validation APIs:
- Move email validation with full profile to providers service
- Deprecate utils `/customer/check-email` endpoint
- Use providers service as single source of truth for user lookups

## Related Issues

- Utils service `/customer/check-email` returning 500 - Can be fixed later
- Database connection issue on utils service - Does not block registration anymore
