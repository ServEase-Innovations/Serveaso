# Netlify Deployment Guide - Same Domain Setup

## Overview

This guide shows how to deploy both the website and booking app on Netlify and host them on the same domain (www.serveaso.com).

## Architecture

```
www.serveaso.com                    (Website - Main site)
    ├── /                           → Home, Services, etc.
    └── /book                       → Iframe embedding booking app
            └── loads from:
                └── serveaso-booking.netlify.app (or /book-app proxy)
```

## 📋 Prerequisites

1. Netlify account (free tier works!)
2. GitHub/GitLab account with your code
3. Custom domain `www.serveaso.com` (optional, can use Netlify subdomains)

## 🚀 Deployment Steps

### Step 1: Deploy Booking App (servase-ui)

#### Option A: Via Netlify UI

1. **Login to Netlify** → https://app.netlify.com
2. **Click "Add new site" → "Import an existing project"**
3. **Connect your Git provider** (GitHub/GitLab)
4. **Select your repository**: `Serveaso-BE`
5. **Configure build settings**:
   ```
   Base directory: apps/servase-ui
   Build command: npm run build:prod
   Publish directory: apps/servase-ui/build
   ```
6. **Add environment variables** (in Site settings → Environment variables):
   ```
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
7. **Deploy!**
8. **Note the URL**: e.g., `serveaso-booking.netlify.app`
9. **Optional**: Change site name in Site settings → Site details → Change site name

#### Option B: Via Netlify CLI

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login
netlify login

# Deploy from servase-ui directory
cd apps/servase-ui
netlify deploy --prod
```

### Step 2: Deploy Website (servease-website)

1. **In Netlify** → "Add new site" → "Import an existing project"
2. **Select your repository**: `Serveaso-BE`
3. **Configure build settings**:
   ```
   Base directory: apps/servease-website
   Build command: npm run build
   Publish directory: apps/servease-website/dist
   ```
4. **Add environment variables**:
   ```
   NODE_VERSION=20
   VITE_BOOKING_URL=https://serveaso-booking.netlify.app
   ```
5. **Deploy!**
6. **Note the URL**: e.g., `serveaso-website.netlify.app`

### Step 3: Configure Custom Domain (www.serveaso.com)

#### For the Website (Primary Domain)

1. **Go to website site** → Site settings → Domain management
2. **Add custom domain**: `www.serveaso.com`
3. **Follow Netlify's DNS instructions**:
   - Add CNAME record: `www` → `serveaso-website.netlify.app`
   - OR use Netlify DNS (easier)
4. **Enable HTTPS**: Netlify does this automatically

#### For the Booking App (Subdomain - Optional)

1. **Go to booking site** → Site settings → Domain management
2. **Add custom domain**: `booking.serveaso.com` (optional)
3. **Or keep using** `serveaso-booking.netlify.app`

## 🔧 Configuration Files Created

### 1. `/apps/servase-ui/netlify.toml`
- Build configuration
- Headers for iframe embedding
- CORS headers
- Cache settings

### 2. `/apps/servease-website/netlify.toml`
- Build configuration
- Proxy/redirect rules
- Security headers
- Cache settings

### 3. Environment Files
- `.env.development` - Local development URLs
- `.env.production` - Production URLs

## 🎯 Two Deployment Strategies

### Strategy A: Direct Iframe (Simpler)
**Website**: `www.serveaso.com`  
**Booking iframe**: `https://serveaso-booking.netlify.app`

**Pros**: 
- Simple setup
- No proxy configuration needed
- Fast deployment

**Cons**:
- Different origin (might have auth/cookie issues)
- Users can see external URL in browser tools

**Setup**:
```bash
# In .env.production
VITE_BOOKING_URL=https://serveaso-booking.netlify.app
```

### Strategy B: Proxy via Same Domain (Recommended)
**Website**: `www.serveaso.com`  
**Booking iframe**: `www.serveaso.com/book-app` (proxied to booking site)

**Pros**: 
- Same origin - cookies/auth work seamlessly
- Cleaner URL structure
- Better for production

**Cons**:
- Requires proxy configuration (already in netlify.toml)

**Setup**:

1. **Update `netlify.toml` in website** (already done):
```toml
[[redirects]]
  from = "/book-app/*"
  to = "https://serveaso-booking.netlify.app/:splat"
  status = 200
  force = true
```

2. **Update `.env.production`**:
```bash
VITE_BOOKING_URL=https://www.serveaso.com/book-app
```

3. **Redeploy website**

## 🔄 Update and Redeploy

### Auto Deploy on Git Push
Both sites auto-deploy when you push to your main branch.

### Manual Deploy via CLI
```bash
# Deploy booking app
cd apps/servase-ui
netlify deploy --prod

# Deploy website
cd apps/servease-website
netlify deploy --prod
```

### Manual Deploy via UI
- Go to site in Netlify
- Click "Deploys"
- Click "Trigger deploy" → "Deploy site"

## 🧪 Testing Production

1. **Visit**: `https://www.serveaso.com`
2. **Click**: "Book a Service"
3. **Should navigate to**: `https://www.serveaso.com/book`
4. **iframe loads**: Booking app
5. **Check browser console** for errors

## 🐛 Troubleshooting

### Issue: Build fails for servase-ui

**Solution**: Check environment variables are set correctly in Netlify

```bash
# Locally test the build
cd apps/servase-ui
npm run build:prod
```

### Issue: Build fails for website

**Solution**: 
```bash
# Check locally
cd apps/servease-website
npm run build
```

### Issue: iframe blocked by CORS

**Solution**: Update headers in `servase-ui/netlify.toml`:
```toml
[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "ALLOW-FROM https://www.serveaso.com"
    Content-Security-Policy = "frame-ancestors 'self' https://www.serveaso.com"
```

### Issue: Booking app shows 404

**Solution**: Ensure SPA fallback is configured in `netlify.toml`:
```toml
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

### Issue: Environment variables not working

**Solution**: 
1. Check they're set in Netlify UI (Site settings → Environment variables)
2. Redeploy after adding variables
3. For Vite, use `VITE_` prefix
4. For React, use `REACT_APP_` prefix

### Issue: Proxy not working

**Solution**: 
1. Check `netlify.toml` redirects
2. Ensure booking app is deployed and accessible
3. Test proxy directly: `https://www.serveaso.com/book-app`

## 📱 Mobile Testing

Test on mobile devices:
```
https://www.serveaso.com
```

Should work seamlessly on iOS and Android.

## 🔐 Security Checklist

- [x] HTTPS enabled on both sites
- [x] CSP headers configured for iframe
- [x] CORS headers set correctly
- [x] X-Frame-Options configured
- [x] Environment variables secured (not in code)
- [ ] Auth cookies configured with correct domain
- [ ] API endpoints using HTTPS
- [ ] Test cross-origin authentication

## 📊 Performance Optimization

### Enable Caching
Already configured in `netlify.toml`:
```toml
[[headers]]
  for = "/assets/*"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"
```

### Enable Compression
Netlify automatically compresses:
- Gzip
- Brotli (if browser supports)

### Optimize Images
Use Netlify's image optimization (paid feature) or:
```bash
npm install -D vite-plugin-imagemin
```

## 💰 Costs

### Netlify Free Tier Includes:
- ✅ 2 sites (website + booking)
- ✅ 100 GB bandwidth/month
- ✅ 300 build minutes/month
- ✅ Automatic HTTPS
- ✅ Continuous deployment
- ✅ Custom domain

**You can run both apps on the free tier!**

## 📋 Deployment Checklist

### Initial Setup
- [ ] Create Netlify account
- [ ] Push code to Git repository
- [ ] Deploy booking app
- [ ] Deploy website
- [ ] Configure environment variables
- [ ] Test both sites on Netlify subdomains

### Custom Domain
- [ ] Purchase/configure `www.serveaso.com`
- [ ] Add domain to Netlify
- [ ] Update DNS records
- [ ] Wait for DNS propagation (can take 24-48 hours)
- [ ] Verify HTTPS certificate

### Final Testing
- [ ] Test website loads: `https://www.serveaso.com`
- [ ] Test all navigation links
- [ ] Click "Book a Service"
- [ ] Verify booking app loads in iframe
- [ ] Test form submissions
- [ ] Test on mobile devices
- [ ] Check browser console for errors

## 🎉 Success!

Your website and booking app are now deployed on Netlify and hosted on the same domain!

**URLs:**
- Website: `https://www.serveaso.com`
- Booking: `https://www.serveaso.com/book` (iframe)

## 📚 Additional Resources

- [Netlify Docs](https://docs.netlify.com/)
- [Custom Domains](https://docs.netlify.com/domains-https/custom-domains/)
- [Redirects & Proxies](https://docs.netlify.com/routing/redirects/)
- [Environment Variables](https://docs.netlify.com/environment-variables/overview/)
