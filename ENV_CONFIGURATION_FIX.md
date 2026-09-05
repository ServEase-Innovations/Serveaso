# Environment Configuration Fix - ServEase UI

## Issue
When running `npm start` in `servase-ui`, it was loading `.env.local` instead of `.env.development`, causing the app to try connecting to localhost endpoints that weren't running.

## Root Cause
Create React App (CRA) has a specific environment file loading priority:
1. `.env.local` (highest priority - always loads)
2. `.env.development` (only if `.env.local` doesn't exist)
3. `.env`

The app had both `.env.local` (localhost URLs) and `.env.development` (Render.com URLs), and `.env.local` was taking precedence.

## Solution Applied

### 1. Renamed `.env.local`
```bash
mv .env.local .env.local.backup
```

This file contained localhost URLs for running the full monorepo locally. It's now backed up and won't interfere.

### 2. Updated `package.json` Scripts
Changed the default `start` command to explicitly load `.env.development`:

**Before:**
```json
"scripts": {
  "start": "env-cmd -f .env.prod craco start",
  ...
}
```

**After:**
```json
"scripts": {
  "start": "env-cmd -f .env.development craco start",
  "start:local": "env-cmd -f .env.local.backup craco start",
  "start:dev": "env-cmd -f .env.dev craco start",
  "start:qa": "env-cmd -f .env.qa craco start",
  "start:prod": "env-cmd -f .env.prod craco start",
  ...
}
```

## Environment Files Overview

### `.env.development` (Default for `npm start`)
- **Purpose**: Development with Render.com backend services
- **URLs**: Points to deployed services on Render.com
- **Use case**: Frontend development without running backend locally
- **Command**: `npm start`

**Endpoints:**
```
REACT_APP_PAYMENTS_URL=https://payments-2z09.onrender.com
REACT_APP_PROVIDER_URL=https://providers-35ix.onrender.com
REACT_APP_PREFERENCES_URL=https://preferences-9dq5.onrender.com
REACT_APP_UTILS_URL=https://utils-j7bu.onrender.com
REACT_APP_REVIEWS_URL=https://reviews-nins.onrender.com
REACT_APP_COUPONS_URL=https://coupons-426f.onrender.com
REACT_APP_TRACKING_API_URL=https://notifications-3i5j.onrender.com
```

### `.env.local.backup` (For local monorepo development)
- **Purpose**: Full-stack local development
- **URLs**: Points to localhost services (requires running monorepo with `npm run dev`)
- **Use case**: When you need to test backend changes locally
- **Command**: `npm run start:local`

**Endpoints:**
```
REACT_APP_PAYMENTS_URL=http://localhost:4100
REACT_APP_PROVIDER_URL=http://localhost:4000
REACT_APP_PREFERENCES_URL=http://localhost:3001
REACT_APP_UTILS_URL=http://localhost:3030
REACT_APP_REVIEWS_URL=http://localhost:5005
REACT_APP_COUPONS_URL=http://localhost:3002
REACT_APP_TRACKING_API_URL=http://localhost:5007/api/tracking
```

### Other Environment Files
- **`.env.dev`**: Development environment (legacy naming)
- **`.env.qa`**: QA/staging environment
- **`.env.prod`**: Production environment

## Usage

### Default Development (Render.com backends)
```bash
cd apps/servase-ui
npm start
```
Uses `.env.development` → connects to Render.com services

### Local Full-Stack Development
```bash
# Terminal 1: Start backend services
cd /path/to/Serveaso-BE
npm run dev

# Terminal 2: Start UI with localhost config
cd apps/servase-ui
npm run start:local
```
Uses `.env.local.backup` → connects to localhost services

### Other Environments
```bash
npm run start:qa      # QA environment
npm run start:prod    # Production environment
```

## Benefits

✅ **Default behavior now matches developer expectations**: `npm start` uses deployed backends
✅ **No need to run full monorepo** for UI development
✅ **Faster iteration** on UI changes
✅ **Local development still possible** with `npm run start:local`
✅ **Clear separation** between local and remote development modes

## Files Changed
- `apps/servase-ui/.env.local` → renamed to `.env.local.backup`
- `apps/servase-ui/package.json` → updated `scripts.start` to use `.env.development`

## Testing
After applying these changes, verify:

1. **Check loaded environment:**
   ```bash
   npm start
   # Open browser console and check: window.location of API calls
   # Should show Render.com URLs
   ```

2. **Verify API connectivity:**
   - Open Network tab in browser DevTools
   - Navigate through the app
   - API calls should go to `https://*.onrender.com` domains

3. **Test location functionality:**
   - Header location button should work
   - Map/location detection should function properly

## Rollback Instructions
If needed, restore the previous setup:
```bash
cd apps/servase-ui
mv .env.local.backup .env.local
# Edit package.json and change start script back to: "start": "env-cmd -f .env.prod craco start"
```

## Related Documentation
- See `MICROFRONTEND_SETUP.md` for deployment configuration
- See `NETLIFY_DEPLOYMENT_GUIDE.md` for production deployment
- See `.env.development` for current endpoint configuration
