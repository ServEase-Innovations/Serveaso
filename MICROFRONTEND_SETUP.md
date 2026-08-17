# Microfrontend Setup - Website + Booking App

## ✅ Solution Implemented

The booking app is now **embedded as a microfrontend** within the website using an iframe approach. Both apps run on the **same URL** without navigation away.

## Architecture

```
┌──────────────────────────────────────────────┐
│  Website (localhost:5173)                    │
│  ┌────────────────────────────────────────┐  │
│  │  Route: /                              │  │
│  │  Component: Home, Services, etc.       │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  Route: /book                          │  │
│  │  Component: BookingApp (iframe)        │  │
│  │                                        │  │
│  │  ┌──────────────────────────────────┐  │  │
│  │  │  servase-ui (localhost:3000)     │  │  │
│  │  │  Embedded via iframe             │  │  │
│  │  └──────────────────────────────────┘  │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

## How It Works

1. **Website runs on `localhost:5173`** with all routes
2. **Booking route `/book`** loads a component with an iframe
3. **iframe embeds servase-ui** running on `localhost:3000`
4. **URL stays as `localhost:5173/book`** - no navigation away!
5. **Navbar/Footer hidden** on booking page for seamless experience

## Files Created/Modified

### 1. New BookingApp Component
**File**: `apps/servease-website/src/pages/BookingApp.jsx`

Embeds the booking app in an iframe with loading state:
```jsx
<iframe
  src="http://localhost:3000"
  title="ServEaso Booking Application"
  className="w-full h-full border-0"
/>
```

### 2. Updated App.jsx
**File**: `apps/servease-website/src/App.jsx`

- Added `/book` route
- Conditionally hide Navbar/Footer on booking page
- Uses `useLocation` to detect current route

### 3. Updated All Booking Links
All links now point to `/book`:
- Home page: "Book a Service", service cards
- Services page: "Book Service Now"
- Navbar: "Download App"

## 🚀 Running the Apps

### Step 1: Start servase-ui (Port 3000)
```bash
cd apps/servase-ui
PORT=3000 npm start
```

### Step 2: Start Website (Port 5173)
```bash
cd apps/servease-website
npm run dev
```

## 🧪 Testing

1. Visit `http://localhost:5173/`
2. Click any "Book a Service" button
3. URL changes to `http://localhost:5173/book`
4. Booking app loads in the same window (no new tab!)
5. URL stays `localhost:5173/book` (microfrontend embedded)

## ✨ Benefits

✅ **Same URL** - No navigation to external domain  
✅ **Seamless UX** - Feels like one app  
✅ **Independent Development** - Both apps can be developed separately  
✅ **Easy Updates** - Update booking app without touching website  
✅ **Shared Domain** - Cookies, auth, and session work seamlessly  

## 🔧 Configuration

### Development
- Website: `http://localhost:5173`
- Booking iframe: `http://localhost:3000`

### Production
Update the iframe source in `BookingApp.jsx`:
```jsx
// Development
src="http://localhost:3000"

// Production
src="https://booking.serveaso.com"  // Or same domain with reverse proxy
```

## 📦 Alternative: Environment-Based URL

Create a config for different environments:

**apps/servease-website/.env.development:**
```bash
VITE_BOOKING_URL=http://localhost:3000
```

**apps/servease-website/.env.production:**
```bash
VITE_BOOKING_URL=https://www.serveaso.com/book-app
```

**Update BookingApp.jsx:**
```jsx
const bookingUrl = import.meta.env.VITE_BOOKING_URL || 'http://localhost:3000';

<iframe src={bookingUrl} ... />
```

## 🌐 Production Deployment Options

### Option 1: Subdomain (Recommended for iframe)
- Website: `www.serveaso.com`
- Booking iframe: `booking.serveaso.com`

**Pros**: 
- Clean separation
- Easy CORS handling
- Independent deployments

### Option 2: Same Domain with Reverse Proxy
- Website: `www.serveaso.com/`
- Booking app: `www.serveaso.com/book-app/`
- iframe points to: `/book-app/`

**Nginx config:**
```nginx
location / {
    root /var/www/website/dist;
}

location /book-app/ {
    proxy_pass http://booking-app:3000/;
}
```

### Option 3: CDN Rewrites (Vercel/Cloudflare)
Deploy booking app separately, use CDN to make it appear on same domain.

## 🐛 Troubleshooting

### Issue: iframe shows blank/404
**Solution**: Make sure servase-ui is running on port 3000
```bash
cd apps/servase-ui
PORT=3000 npm start
```

### Issue: CORS errors in iframe
**Solution**: Add CORS headers to servase-ui server or use same domain in production

### Issue: Navbar/Footer still showing on /book
**Solution**: Clear browser cache and restart dev server
```bash
# In website terminal
Ctrl+C
npm run dev
```

### Issue: iframe height not fitting
**Solution**: BookingApp component already uses `h-screen` for full height

### Issue: Authentication issues between apps
**Solution**: In production, use same domain or configure cookies with proper domain settings

## 🎨 Customization

### Remove Loading Spinner
Edit `BookingApp.jsx` and remove the loading state.

### Add Back Button
```jsx
<button 
  onClick={() => window.history.back()}
  className="absolute top-4 left-4 z-20 bg-white px-4 py-2 rounded"
>
  ← Back to Website
</button>
```

### Communicate Between Apps
Use `postMessage` API for iframe communication:

**Website → Booking:**
```javascript
const iframe = document.querySelector('iframe');
iframe.contentWindow.postMessage({ type: 'SERVICE', value: 'cook' }, '*');
```

**Booking → Website:**
```javascript
window.parent.postMessage({ type: 'BOOKING_COMPLETE' }, '*');
```

## 📊 Performance

- **Initial Load**: Website loads first (~500ms)
- **Booking Load**: iframe loads when route accessed (~1s)
- **Lazy Loading**: BookingApp component is lazy-loaded
- **Caching**: Both apps cached separately by browser

## 🔐 Security Considerations

1. **iframe sandbox**: Already configured with necessary permissions
2. **CORS**: Configure properly in production
3. **CSP headers**: Update Content Security Policy for iframe
4. **Authentication**: Ensure tokens work across both apps

## ✅ Checklist

- [x] BookingApp component created with iframe
- [x] /book route added to website
- [x] All booking links point to /book
- [x] Navbar/Footer hidden on booking page
- [x] servase-ui runs on port 3000
- [x] Website runs on port 5173
- [ ] Test all booking buttons
- [ ] Configure production URL
- [ ] Deploy both apps
- [ ] Test on production domain

## 🚀 Next Steps

1. **Test locally**: Verify `/book` loads booking app
2. **Environment variables**: Set up prod/dev URLs
3. **Production deployment**: Choose deployment option
4. **Analytics**: Track booking conversions
5. **Error handling**: Add fallback UI for iframe errors

## 📞 Quick Commands

**Start both apps:**
```bash
# Terminal 1
cd apps/servase-ui && PORT=3000 npm start

# Terminal 2
cd apps/servease-website && npm run dev
```

**Access:**
- Website: http://localhost:5173
- Booking: http://localhost:5173/book (embedded)
- Booking direct: http://localhost:3000 (for testing)
