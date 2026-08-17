# 🚀 Netlify Deployment - Quick Start Guide

## ⚡ 5-Minute Setup

### Step 1: Deploy Booking App
1. Go to [Netlify](https://app.netlify.com)
2. **Add new site** → Import from Git
3. Configure:
   ```
   Base: apps/servase-ui
   Build: npm run build:prod
   Publish: apps/servase-ui/build
   ```
4. Result: `https://serveaso-booking.netlify.app` ✅

### Step 2: Deploy Website
1. **Add new site** → Import from Git
2. Configure:
   ```
   Base: apps/servease-website
   Build: npm run build
   Publish: apps/servease-website/dist
   ```
3. Add environment variable:
   ```
   VITE_BOOKING_URL=https://serveaso-booking.netlify.app
   ```
4. Result: `https://serveaso-website.netlify.app` ✅

### Step 3: Add Custom Domain (Optional)
1. **Website site** → Domain settings
2. Add domain: `www.serveaso.com`
3. Update DNS as instructed
4. Result: `https://www.serveaso.com` ✅

## 🎯 URL Structure

```
Production:
www.serveaso.com/          → Website home
www.serveaso.com/services  → Services page
www.serveaso.com/book      → Booking app (iframe)

iframe loads from:
→ serveaso-booking.netlify.app
```

## ✅ Files Already Configured

- ✅ `apps/servase-ui/netlify.toml`
- ✅ `apps/servease-website/netlify.toml`
- ✅ `apps/servease-website/.env.production`
- ✅ `apps/servease-website/src/pages/BookingApp.jsx`

## 📋 Environment Variables Needed

### For Booking App (servase-ui):
```bash
NODE_VERSION=20
CI=false
REACT_APP_ENV=production
REACT_APP_PAYMENTS_URL=https://payments-vyqp.onrender.com
REACT_APP_PROVIDER_URL=https://providers-k8w7.onrender.com
REACT_APP_PREFERENCES_URL=https://preferences.onrender.com
REACT_APP_UTILS_URL=https://utils-jo6c.onrender.com
REACT_APP_REVIEWS_URL=https://reviews-7aal.onrender.com
REACT_APP_COUPONS_URL=https://coupons-o26r.onrender.com
REACT_APP_TICKETS_URL=https://tickets-3gc8.onrender.com
REACT_APP_CHAT_URL=https://chat-b3wl.onrender.com
REACT_APP_IMAGE_UPLOADER_URL=https://imageuploader-5njj.onrender.com
REACT_APP_TRACKING_API_URL=https://notifications-mjdp.onrender.com
REACT_APP_AUTH0_DOMAIN=dev-plavkbiy7v55pbg4.us.auth0.com
REACT_APP_AUTH0_CLIENT_ID=FkZvRgSNTXloPOo2ZVRmt24MbTrfIusi
```

### For Website (servease-website):
```bash
NODE_VERSION=20
VITE_BOOKING_URL=https://serveaso-booking.netlify.app
```

## 🎨 Two Strategies

### Option A: Simple (Recommended for Start)
Iframe loads from Netlify subdomain:
```
VITE_BOOKING_URL=https://serveaso-booking.netlify.app
```

### Option B: Same Domain (Better for Production)
Iframe loads from main domain via proxy:
```
VITE_BOOKING_URL=https://www.serveaso.com/book-app
```
(Requires custom domain setup)

## 🔄 Auto-Deploy

Once connected to Git, both sites auto-deploy when you push code!

```bash
git add .
git commit -m "Update website"
git push origin main
# Netlify auto-deploys! 🎉
```

## 📞 Need Help?

See full guide: `NETLIFY_DEPLOYMENT_GUIDE.md`

## 🎉 That's It!

Your microfrontend architecture is now live on Netlify!
