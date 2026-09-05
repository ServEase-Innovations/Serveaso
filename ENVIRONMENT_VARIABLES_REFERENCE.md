# Environment Variables Reference

## Quick Reference - All Apps Use Same Names

Both **ServEase UI (web)** and **ServEase iOS (mobile)** use **identical** environment variable names.

### API Endpoints

```bash
# Core Services
REACT_APP_PAYMENTS_URL=http://localhost:4100
REACT_APP_PROVIDER_URL=http://localhost:4000
REACT_APP_PREFERENCES_URL=http://localhost:3001
REACT_APP_UTILS_URL=http://localhost:3030
REACT_APP_REVIEWS_URL=http://localhost:5005
REACT_APP_TICKETS_URL=http://localhost:5006
REACT_APP_COUPONS_URL=http://localhost:3002
REACT_APP_CHAT_URL=http://localhost:5001
REACT_APP_IMAGE_UPLOADER_URL=http://localhost:5003
REACT_APP_TRACKING_API_URL=http://localhost:5007

# WebSocket Endpoints
REACT_APP_UTILS_WS_URL=ws://localhost:3030
REACT_APP_TRACKING_WS_URL=ws://localhost:5007

# Secrets
REACT_APP_GOOGLE_MAPS_API_KEY=your_key_here
REACT_APP_RAZORPAY_KEY=rzp_test_xxxxx
REACT_APP_ADMIN_PUSH_SECRET=your_secret
REACT_APP_ADMIN_TICKET_SECRET=your_secret
REACT_APP_ADMIN_EMAIL=admin@serveaso.com
REACT_APP_CHAT_ADMIN_ID=698ace8b8ea84c91bdc93678
```

## Production URLs (Render)

```bash
# Core Services
REACT_APP_PAYMENTS_URL=https://payments-vyqp.onrender.com
REACT_APP_PROVIDER_URL=https://providers-da9c6dp42hec73fergtg.onrender.com
REACT_APP_PREFERENCES_URL=https://preferences-6leu.onrender.com
REACT_APP_UTILS_URL=https://utils-qhvi.onrender.com
REACT_APP_REVIEWS_URL=https://reviews-4mls.onrender.com
REACT_APP_TICKETS_URL=https://tickets-1cfe.onrender.com
REACT_APP_COUPONS_URL=https://coupons-s9zq.onrender.com
REACT_APP_CHAT_URL=https://chat-b3wl.onrender.com
REACT_APP_IMAGE_UPLOADER_URL=https://imageuploader-5njj.onrender.com
REACT_APP_TRACKING_API_URL=https://tracking-api.onrender.com

# WebSocket Endpoints
REACT_APP_UTILS_WS_URL=wss://utils-qhvi.onrender.com
REACT_APP_TRACKING_WS_URL=wss://tracking-api.onrender.com
```

## Service Port Mapping (Development)

| Service | Port | Environment Variable |
|---------|------|---------------------|
| Providers | 4000 | `REACT_APP_PROVIDER_URL` |
| Preferences | 3001 | `REACT_APP_PREFERENCES_URL` |
| Coupons | 3002 | `REACT_APP_COUPONS_URL` |
| Utils | 3030 | `REACT_APP_UTILS_URL` |
| Payments | 4100 | `REACT_APP_PAYMENTS_URL` |
| Chat | 5001 | `REACT_APP_CHAT_URL` |
| Image Uploader | 5003 | `REACT_APP_IMAGE_UPLOADER_URL` |
| Reviews | 5005 | `REACT_APP_REVIEWS_URL` |
| Tickets | 5006 | `REACT_APP_TICKETS_URL` |
| Tracking | 5007 | `REACT_APP_TRACKING_API_URL` |

## Where to Set Variables

### Web App (Netlify)

Set in **Netlify Dashboard** → Site Settings → Environment Variables:
1. Go to https://app.netlify.com
2. Select your site
3. Site settings → Build & deploy → Environment
4. Add variables

**Build command:** `npm run build`  
**Publish directory:** `dist`

### Mobile App (iOS/Android)

**Development:**
- Edit `.env.development` file
- Runs automatically with `npm run ios` or `npm run android`

**Production:**
- Edit `.env.production` file
- Or set in Xcode build settings (iOS)
- Or set in `android/app/build.gradle` (Android)

### Backend Services (Render)

Set in **Render Dashboard** → Service → Environment:
1. Go to https://dashboard.render.com
2. Select your service
3. Click Environment tab
4. Add key-value pairs
5. Save and redeploy

## Naming Convention

✅ **Always use `REACT_APP_` prefix**  
✅ **Use `_URL` suffix for HTTP endpoints**  
✅ **Use `_WS_URL` suffix for WebSocket endpoints**  
✅ **Same names work in web and mobile**

## Examples

### Override Single Endpoint

```bash
# Development with custom payments URL
REACT_APP_PAYMENTS_URL=https://my-dev-payments.com npm start
```

### Share .env Between Projects

```bash
# Copy web .env to mobile
cp apps/servase-ui/.env.development apps/servease-ios/.env.development
```

### Check Current Configuration

**Web:**
```javascript
import { printConfig } from './config/environments';
printConfig(); // Logs all endpoints
```

**Mobile:**
```typescript
import { API_URLS } from './config/apiUrls';
console.log(API_URLS); // Shows all URLs
```

## Troubleshooting

**Problem:** Variables not loaded  
**Solution:** Ensure file is named `.env.development` or `.env.production` (not `.env`)

**Problem:** Changes not applied  
**Solution:** Restart dev server or rebuild app

**Problem:** Mobile app can't connect on physical device  
**Solution:** Create `devApi.local.ts` with your LAN IP (iOS only)

## Documentation

- Web: `apps/servase-ui/ENVIRONMENT_CONFIG.md`
- Mobile: `apps/servease-ios/ENVIRONMENT_CONFIG.md`
- Summary: `ENVIRONMENT_CONFIG_SUMMARY.md`
