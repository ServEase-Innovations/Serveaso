# Final Setup Guide - Website + Booking Integration

## Overview
The website and booking app run on **separate ports** in development and are unified in production via reverse proxy/CDN configuration.

## Development Setup

### Port Configuration
- **Website**: `http://localhost:5173`
- **Booking App**: `http://localhost:3000`

### How It Works
- All "Book a Service" buttons redirect to `http://localhost:3000`
- In production, these will redirect to `https://www.serveaso.com/book`

## 🚀 Running the Apps

### Start Both Apps (Two Terminals)

**Terminal 1 - servase-ui (Booking App):**
```bash
cd apps/servase-ui
PORT=3000 npm start
```

**Terminal 2 - Website:**
```bash
cd apps/servease-website
npm run dev
```

### Alternative: Using Root Scripts

**Terminal 1:**
```bash
npm run dev:ui
```

**Terminal 2:**
```bash
npm run dev:website
```

## 🧪 Testing

1. Visit `http://localhost:5173/` (website)
2. Click any "Book a Service" button
3. Should navigate to `http://localhost:3000` (booking app)

## 📝 Current Configuration

### Files Modified

1. **apps/servease-website/vite.config.js**
   - Removed proxy configuration (not needed for dev)
   - Port set to 5173

2. **apps/servase-ui/.env.local**
   - Added `PORT=3000`

3. **All booking links updated:**
   - Development: Point to `http://localhost:3000`
   - Production: Will use `https://www.serveaso.com/book`

### Configuration File Created

**apps/servease-website/src/config.js**
```javascript
// Manages URLs for different environments
development: { bookingAppUrl: 'http://localhost:3000' }
production: { bookingAppUrl: 'https://www.serveaso.com/book' }
```

## 🌐 Production Deployment

For production (`www.serveaso.com`), you need to configure a reverse proxy or CDN to serve both apps on the same domain.

### Option 1: Nginx Reverse Proxy

```nginx
server {
    listen 80;
    server_name www.serveaso.com;

    # Root - serve website
    location / {
        root /var/www/servease-website/dist;
        try_files $uri $uri/ /index.html;
    }

    # /book - serve booking app
    location /book {
        root /var/www/servase-ui/build;
        try_files $uri $uri/ /index.html;
    }
}
```

### Option 2: Cloudflare/Vercel Rewrites

Deploy each app separately and use rewrites:

**Vercel vercel.json:**
```json
{
  "rewrites": [
    {
      "source": "/book/:path*",
      "destination": "https://booking-app-domain.vercel.app/:path*"
    }
  ]
}
```

**Cloudflare Page Rules:**
- Forward URL: `www.serveaso.com/book/*` → `booking-app.pages.dev/*`

### Option 3: Separate Subdomains

- Website: `www.serveaso.com`
- Booking: `book.serveaso.com`

Then update the booking links to point to the subdomain.

## 📂 Project Structure

```
Serveaso-BE/
├── apps/
│   ├── servease-website/       # Marketing website (Vite + React)
│   │   ├── src/
│   │   │   ├── config.js       # Environment config
│   │   │   ├── pages/
│   │   │   │   ├── Home.jsx    # Updated with booking links
│   │   │   │   └── Services.jsx
│   │   │   └── components/
│   │   │       └── Navbar.jsx   # Updated with booking links
│   │   ├── vite.config.js      # Port 5173
│   │   └── package.json
│   │
│   └── servase-ui/             # Booking application (React)
│       ├── .env.local          # PORT=3000
│       ├── src/
│       │   └── index.tsx       # /book route added
│       └── package.json
│
└── services/                   # Backend microservices
    ├── payments/
    ├── providers/
    └── ...
```

## 🔧 Environment Variables

### Website (.env for production)
```bash
VITE_BOOKING_URL=https://www.serveaso.com/book
```

### Booking App (.env.local)
```bash
PORT=3000
# ... other API URLs
```

## ❗ Important Notes

1. **Development**: Apps run on different ports - this is normal and expected
2. **Production**: Must be configured with reverse proxy or CDN rewrites
3. **CORS**: Not an issue since they're on the same domain in production
4. **Auth**: Ensure cookies/tokens work across both apps in production

## 🐛 Troubleshooting

### Issue: servase-ui won't start on port 3000
```bash
# Find process using port 3000
lsof -i :3000

# Kill the process
kill -9 <PID>

# Or use a different port
PORT=3001 npm start
```
Then update the links in the website to use `http://localhost:3001`

### Issue: Website shows blank page
```bash
# Clear cache and restart
rm -rf apps/servease-website/node_modules/.vite
cd apps/servease-website
npm run dev
```

### Issue: Links don't work after changes
- Hard refresh browser (Cmd+Shift+R on Mac, Ctrl+Shift+R on Windows)
- Clear browser cache
- Restart dev servers

## ✅ Checklist

- [x] Website runs on port 5173
- [x] servase-ui runs on port 3000
- [x] All "Book a Service" links point to localhost:3000
- [x] Config file created for environment management
- [x] /book route added to servase-ui
- [ ] Test all booking buttons work
- [ ] Configure production reverse proxy
- [ ] Deploy to production
- [ ] Test production URLs

## 🎯 Next Steps

1. **Test locally**: Make sure both apps run and links work
2. **Choose production deployment**: Nginx, Vercel, Cloudflare, etc.
3. **Update production URLs**: Change from localhost to production domain
4. **Test production**: Verify everything works on live domain
5. **Monitor**: Set up analytics to track booking conversions

## 📞 Quick Reference

**Start development:**
```bash
# Terminal 1
cd apps/servase-ui && PORT=3000 npm start

# Terminal 2
cd apps/servease-website && npm run dev
```

**Access URLs:**
- Website: http://localhost:5173
- Booking: http://localhost:3000

**Production URLs:**
- Website: https://www.serveaso.com
- Booking: https://www.serveaso.com/book
