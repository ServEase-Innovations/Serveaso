# Environment Configuration System - Summary

## What Was Created

Centralized environment configuration system for **ServEase UI** (web) and **iOS/React Native** apps to easily switch between development and production API endpoints.

## Changes Made

### 1. ServEase UI (Web App)

**Files Created:**
- `apps/servase-ui/src/config/environments.ts` - Environment-specific configs
- `apps/servase-ui/.env.development` - Development environment variables
- `apps/servase-ui/.env.production` - Production environment variables  
- `apps/servase-ui/ENVIRONMENT_CONFIG.md` - Documentation

**Files Modified:**
- `apps/servase-ui/src/config/urls.ts` - Now uses centralized config

**Commit:** `14053d5` - "Add centralized environment configuration system for dev/prod endpoints"

### 2. ServEase iOS (React Native App)

**Files Created:**
- `apps/servease-ios/.env.development` - Development environment variables
- `apps/servease-ios/.env.production` - Production environment variables
- `apps/servease-ios/ENVIRONMENT_CONFIG.md` - Documentation

**Files Modified:**
- `apps/servease-ios/src/config/apiUrls.ts` - Now auto-detects dev/prod

**Commit:** `9ed43c5` - "Add centralized environment configuration system for dev/prod endpoints"

## How It Works

### Web App (ServEase UI)

```typescript
// Automatically uses correct endpoints based on NODE_ENV
import { urls } from './config/urls';

// Uses localhost in development, Render in production
const paymentsUrl = urls.payments;
```

**Development Mode:**
```bash
npm start  # Uses .env.development (localhost)
```

**Production Mode:**
```bash
npm run build  # Uses .env.production (Render URLs)
```

### Mobile App (ServEase iOS)

```typescript
// Automatically uses correct endpoints based on __DEV__
import { API_URLS } from './config/apiUrls';

// Uses localhost in dev, Render in production
const paymentsUrl = API_URLS.payments;
```

**Development Mode:**
```bash
npm run ios     # Uses localhost (simulator)
npm run android # Uses localhost (emulator)
```

**Physical Device Testing:**
```typescript
// Create src/config/devApi.local.ts
export const DEV_LAN_HOST = "192.168.1.100"; // Your computer's LAN IP
```

**Production Mode:**
```bash
npm run ios --configuration Release
npm run android --variant=release
```

## Endpoint Mappings

| Service | Development | Production |
|---------|-------------|------------|
| **Payments** | `localhost:4100` | `payments-vyqp.onrender.com` |
| **Providers** | `localhost:4000` | `providers-da9c6dp42hec73fergtg.onrender.com` |
| **Utils** | `localhost:3030` | `utils-qhvi.onrender.com` |
| **Preferences** | `localhost:3001` | `preferences-6leu.onrender.com` |
| **Reviews** | `localhost:5005` | `reviews-4mls.onrender.com` |
| **Tickets** | `localhost:5006` | `tickets-1cfe.onrender.com` |
| **Coupons** | `localhost:3002` | `coupons-s9zq.onrender.com` |
| **Chat** | `localhost:5001` | `chat-b3wl.onrender.com` |
| **Image Uploader** | `localhost:5003` | `imageuploader-5njj.onrender.com` |
| **Tracking** | `localhost:5007` | `tracking-api.onrender.com` |

## Benefits

✅ **Single source of truth** - All endpoints defined in one place  
✅ **Easy switching** - Automatic dev/prod detection  
✅ **Environment variables** - Can override any endpoint  
✅ **Better documentation** - Clear guides for each app  
✅ **Type safety** - TypeScript interfaces for all configs  
✅ **Physical device support** - Easy LAN IP override for mobile  
✅ **No code changes needed** - Existing code works without modifications

## Usage Examples

### Update Production Endpoint

**Web:**
```typescript
// Edit apps/servase-ui/src/config/environments.ts
export const productionConfig = {
  endpoints: {
    payments: 'https://new-payments-url.com', // Updated
    // ...
  },
};
```

**Mobile:**
```typescript
// Edit apps/servease-ios/src/config/apiUrls.ts
const PRODUCTION_URLS = {
  payments: 'https://new-payments-url.com', // Updated
  // ...
};
```

### Override via Environment Variable

**Web (Netlify):**
Set environment variable in Netlify dashboard:
```
REACT_APP_PAYMENTS_URL=https://custom-url.com
```

**Mobile:**
Edit `.env.production`:
```
PAYMENTS_API_URL=https://custom-url.com
```

## Documentation

Detailed guides available in:
- Web: `apps/servase-ui/ENVIRONMENT_CONFIG.md`
- Mobile: `apps/servease-ios/ENVIRONMENT_CONFIG.md`

## Next Steps

1. **Update Render URLs** - Replace placeholder URLs with actual Render service URLs
2. **Set Production Secrets** - Add API keys to Netlify (web) and Xcode/Android Studio (mobile)
3. **Test Deployments** - Verify production builds connect to correct endpoints
4. **Update Documentation** - Add any team-specific configuration notes

## Troubleshooting

**Problem:** App connects to wrong endpoint  
**Solution:** Check `NODE_ENV` or `__DEV__` flag, verify .env file is correct

**Problem:** Physical device can't connect  
**Solution:** Create `devApi.local.ts` with your LAN IP (mobile only)

**Problem:** Production build using localhost  
**Solution:** Ensure build command uses production env (e.g., `npm run build`, not `npm start`)

## Repository Links

- **Web App:** https://github.com/ServEase-Innovations/ServEase_UI
- **Mobile App:** https://github.com/ServEase-Innovations/servease_ios
- **Monorepo:** https://github.com/ServEase-Innovations/Serveaso
