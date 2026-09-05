# Fixing "Site not found" 404 Error on Netlify

## Understanding the Issue

The "Site not found" error can happen for several reasons:

### 1. **Build Failed or Incomplete**
The site built but didn't deploy properly.

### 2. **Wrong URL**
You're accessing the wrong Netlify URL.

### 3. **Custom Domain Not Configured**
If using a custom domain, DNS might not be set up yet.

### 4. **Build Output Missing**
The build succeeded but the output directory is empty.

---

## 🔍 Troubleshooting Steps

### Step 1: Verify Build Success

1. Go to Netlify Dashboard
2. Click on your site
3. Go to "Deploys" tab
4. Check if the latest deploy shows **"Published"** in green

If it shows **"Failed"**, click on it to see the build logs.

---

### Step 2: Check the Correct URL

Your Netlify URL should be:
```
https://[your-site-name].netlify.app
```

**Common mistakes:**
- ❌ `https://netlify.app` (missing site name)
- ❌ `https://[site-name].com` (using custom domain that's not set up)
- ✅ `https://serveaso-website.netlify.app` (correct format)

**Find your URL:**
1. Netlify Dashboard → Your site
2. Look at the top for the site URL
3. Copy and use that exact URL

---

### Step 3: Check Build Output

In the deploy logs, look for:

**For Website (Vite):**
```
✓ built in [time]
dist/index.html                  [size]
dist/assets/index-[hash].js      [size]
dist/assets/index-[hash].css     [size]
```

**For Booking App (React):**
```
Compiled successfully!
File sizes after gzip:
  [size]  build/static/js/[hash].js
  [size]  build/static/css/[hash].css
```

If you don't see these, the build failed.

---

### Step 4: Verify Redirects are Working

The `_redirects` file should be in the published output:

**Check in deploy log:**
```
dist/_redirects
```
OR
```
build/_redirects
```

If missing, the SPA fallback won't work.

---

## ✅ Quick Fixes

### Fix 1: Clear Cache and Redeploy

1. Go to **Deploys** tab
2. Click **"Trigger deploy"**
3. Select **"Clear cache and deploy site"**
4. Wait for build to complete

### Fix 2: Verify Environment Variables

Both apps need environment variables set:

**Website:**
```bash
NODE_VERSION=20
VITE_BOOKING_URL=https://[your-booking-app].netlify.app
```

**Booking App:**
```bash
NODE_VERSION=20
CI=false
REACT_APP_ENV=production
# ... all other REACT_APP_* variables
```

**To check:**
1. Site settings → Environment variables
2. Verify all required variables are set
3. If missing, add them and redeploy

### Fix 3: Check Build Settings

**Website:**
```
Build command:      npm run build
Publish directory:  dist
```

**Booking App:**
```
Build command:      npm run build
Publish directory:  build
```

**To check:**
1. Site settings → Build & deploy
2. Scroll to "Build settings"
3. Verify settings match above

---

## 🧪 Testing After Deploy

### For Website:

1. Visit: `https://[your-site].netlify.app`
2. Should see the homepage ✅
3. Try: `https://[your-site].netlify.app/services`
4. Should show services page (not 404) ✅
5. Try: `https://[your-site].netlify.app/book`
6. Should show booking iframe ✅

### For Booking App:

1. Visit: `https://[your-booking].netlify.app`
2. Should see the booking interface ✅
3. Try any route like `/cook` or `/maid`
4. Should work (not 404) ✅

---

## 🚨 Common Issues

### Issue: "Page Not Found" After Clicking Links

**Cause:** SPA redirects not working  
**Fix:** Ensure `_redirects` file is in `public/` folder

```bash
# For website
echo "/*    /index.html   200" > apps/servease-website/public/_redirects

# For booking app
echo "/*    /index.html   200" > apps/servase-ui/public/_redirects
```

Then commit and push.

### Issue: Build Succeeds but Site Shows Blank

**Cause:** Missing environment variables  
**Fix:** Add all required env vars in Netlify UI

### Issue: Custom Domain Shows 404

**Cause:** DNS not configured  
**Fix:** 
1. Site settings → Domain management
2. Check DNS configuration
3. Wait 24-48 hours for propagation

### Issue: Some Routes Work, Others Don't

**Cause:** Partial routing issue  
**Fix:** Check React Router configuration in your app

---

## 📋 Deployment Checklist

Use this to verify everything is correct:

### Website Checklist:
- [ ] Repository: `ServEaso_websit` connected
- [ ] Branch: `uddate/new_feel` selected
- [ ] Build command: `npm run build`
- [ ] Publish directory: `dist`
- [ ] Environment variable: `VITE_BOOKING_URL` set
- [ ] Build status: Published (green)
- [ ] Site loads at Netlify URL
- [ ] `/services` route works
- [ ] `/book` route works

### Booking App Checklist:
- [ ] Repository: `ServEase_UI` connected
- [ ] Branch: `main` selected
- [ ] Build command: `npm run build`
- [ ] Publish directory: `build`
- [ ] All `REACT_APP_*` env vars set
- [ ] Build status: Published (green)
- [ ] Site loads at Netlify URL
- [ ] Login/auth works
- [ ] Can navigate between pages

---

## 🔗 What's Your Exact Error?

### Error 1: "Site not found" with Netlify Internal ID

**You're accessing:** A URL that doesn't exist  
**Solution:** Use the correct Netlify URL from your dashboard

### Error 2: "Page not found" on your actual site

**Cause:** SPA routing issue  
**Solution:** Check `_redirects` file and netlify.toml

### Error 3: Build failed

**Solution:** Check build logs for errors and fix them

---

## 📞 Share These for Help:

If still having issues, share:

1. **Exact URL** you're trying to access
2. **Netlify site name** (from dashboard)
3. **Deploy log** (last 50 lines)
4. **Build settings** screenshot
5. **Error message** (full text)

---

## ✅ Expected Working URLs:

After successful deployment:

```
Website:
https://[your-website-name].netlify.app          → Homepage
https://[your-website-name].netlify.app/services → Services page
https://[your-website-name].netlify.app/book     → Booking iframe

Booking App:
https://[your-booking-name].netlify.app          → Booking interface
https://[your-booking-name].netlify.app/cook     → Cook service
```

Replace `[your-website-name]` and `[your-booking-name]` with your actual Netlify site names.
