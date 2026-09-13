# iOS Environment Configuration - .env.development Support

## Changes Made

Added support for `.env.development` file in the React Native iOS app, matching the behavior of the web app (servase-ui).

### 1. Installed `react-native-dotenv`
```bash
npm install --save-dev react-native-dotenv
```

This Babel plugin allows React Native to load environment variables from `.env` files.

### 2. Updated `babel.config.js`
Configured the plugin to load `.env.development` by default:

```javascript
module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: [
    [
      'module:react-native-dotenv',
      {
        envName: 'APP_ENV',
        moduleName: '@env',
        path: '.env.development', // Load .env.development by default
        safe: false,
        allowUndefined: true,
        verbose: false,
      },
    ],
  ],
};
```

### 3. Created TypeScript Definitions
**File**: `src/types/env.d.ts`

Provides type safety for environment variables imported from `@env`:
- `REACT_APP_PAYMENTS_URL`
- `REACT_APP_PROVIDER_URL`
- `REACT_APP_UTILS_URL`
- `REACT_APP_PREFERENCES_URL`
- `REACT_APP_REVIEWS_URL`
- `REACT_APP_TICKETS_URL`
- `REACT_APP_COUPONS_URL`
- `REACT_APP_CHAT_URL`
- `REACT_APP_IMAGE_UPLOADER_URL`
- `REACT_APP_TRACKING_API_URL`
- `REACT_APP_TRACKING_WS_URL`
- `REACT_APP_GOOGLE_MAPS_API_KEY`
- `REACT_APP_RAZORPAY_KEY`
- And other config values

### 4. Updated `src/config/apiUrls.ts`
Changed from using `process.env.*` to importing from `@env`:

**Before:**
```typescript
const DEVELOPMENT_URLS = {
  payments: process.env.REACT_APP_PAYMENTS_URL || 'http://localhost:4100',
  // ...
};
```

**After:**
```typescript
import {
  REACT_APP_PAYMENTS_URL,
  REACT_APP_PROVIDER_URL,
  // ... other imports
} from '@env';

const DEVELOPMENT_URLS = {
  payments: REACT_APP_PAYMENTS_URL || 'http://localhost:4100',
  // ...
};
```

## How It Works

### Development Mode (`npm run ios`)
1. Babel plugin loads `.env.development`
2. Variables are injected at build time
3. App connects to Render.com endpoints by default
4. Console logs show which endpoints are loaded

### Environment File Priority
- `.env.development` (default for development builds)
- `.env.local` (if you create it, overrides .env.development)
- `.env` (fallback)

### Current Configuration

**From `.env.development`:**
```env
REACT_APP_PAYMENTS_URL=https://payments-2z09.onrender.com
REACT_APP_PROVIDER_URL=https://providers-35ix.onrender.com
REACT_APP_PREFERENCES_URL=https://preferences-9dq5.onrender.com
REACT_APP_UTILS_URL=https://utils-j7bu.onrender.com
REACT_APP_REVIEWS_URL=https://reviews-nins.onrender.com
REACT_APP_TICKETS_URL=https://tickets-8wjl.onrender.com
REACT_APP_COUPONS_URL=https://coupons-426f.onrender.com
REACT_APP_CHAT_URL=https://chat-gzsg.onrender.com
REACT_APP_TRACKING_API_URL=https://notifications-3i5j.onrender.com
# ... and other config values
```

## Usage

### Default Development Build
```bash
cd apps/servease-ios
npm run ios
```
✅ Automatically loads `.env.development`  
✅ Connects to Render.com services  
✅ No need to modify code  

### For Local Backend Development
Create `.env.local` (will override `.env.development`):
```env
REACT_APP_PAYMENTS_URL=http://localhost:4100
REACT_APP_PROVIDER_URL=http://localhost:4000
# ... other localhost URLs
```

Then run:
```bash
npm run ios
```

### Physical Device Testing
For testing on physical devices with local backend:

**Option 1**: Use `.env.local` with your Mac's LAN IP
```env
REACT_APP_PAYMENTS_URL=http://192.168.1.100:4100
REACT_APP_PROVIDER_URL=http://192.168.1.100:4000
# Replace 192.168.1.100 with your Mac's IP
```

**Option 2**: Keep using the existing `devApi.local.ts` approach

### Verify Configuration
When the app starts, check the console output:
```
🔧 API Configuration: DEVELOPMENT
📡 Loaded from .env.development
🌐 Endpoints: {
  payments: 'https://payments-2z09.onrender.com',
  providers: 'https://providers-35ix.onrender.com',
  ...
}
```

## Important Notes

### 1. Clean Build Required
After changing Babel config, you MUST clean and rebuild:
```bash
cd apps/servease-ios

# Clean
rm -rf ios/build
rm -rf ios/Pods
rm -rf node_modules

# Reinstall
npm install
cd ios && pod install && cd ..

# Build
npm run ios
```

### 2. Metro Cache
If changes don't take effect, reset Metro cache:
```bash
npm run start:reset
```

### 3. Environment Variables are Build-Time
Environment variables are injected at **build time**, not runtime. If you change `.env.development`, you need to:
1. Stop the app
2. Clear Metro cache (or restart Metro with `npm run start:reset`)
3. Rebuild the app (`npm run ios`)

### 4. TypeScript Support
The `src/types/env.d.ts` file provides autocomplete and type checking for environment variables:
```typescript
import { REACT_APP_PAYMENTS_URL } from '@env';
// TypeScript knows this is a string ✅
```

## Benefits

✅ **Consistency**: Same env variable names as web app  
✅ **No code changes**: Just update `.env.development`  
✅ **Type safety**: TypeScript definitions for all env vars  
✅ **Flexible**: Can override with `.env.local`  
✅ **Developer-friendly**: Clear console logs showing config  
✅ **Works with Xcode**: Env vars available in iOS builds  

## Troubleshooting

### Environment variables not loading?
1. Clear Metro cache: `npm run start:reset`
2. Clean build: `rm -rf ios/build`
3. Reinstall pods: `cd ios && pod install`
4. Rebuild app: `npm run ios`

### Wrong endpoints being used?
Check the console logs when app starts - it shows which config is loaded.

### TypeScript errors for `@env`?
Make sure `src/types/env.d.ts` exists and is included in your `tsconfig.json`.

### Still using localhost on device?
Create `.env.local` with your Mac's LAN IP or use Render.com URLs from `.env.development`.

## Files Modified
- `package.json` - Added `react-native-dotenv` dependency
- `babel.config.js` - Added dotenv plugin configuration
- `src/types/env.d.ts` - Created TypeScript definitions
- `src/config/apiUrls.ts` - Updated to import from `@env`

## Files Not Changed
- `.env.development` - Already exists with correct URLs
- `src/config/devApi.ts` - Still works for utils/preferences fallbacks
- Package.json scripts - No changes needed

## Testing Checklist
- [ ] Clean build and reinstall dependencies
- [ ] Run `npm run ios`
- [ ] Check console for "Loaded from .env.development"
- [ ] Verify API calls go to Render.com URLs
- [ ] Test on simulator
- [ ] Test on physical device (if applicable)

## Related Documentation
- See `ENV_CONFIGURATION_FIX.md` for web app (servase-ui) environment setup
- See `.env.development` for current endpoint configuration
- See `DEPLOYMENT_CHECKLIST.md` for production configuration
