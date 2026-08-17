# Website + Booking App Proxy Setup Guide

## Overview
This setup allows both the website and booking app to appear on the same domain using a proxy configuration:
- **Website**: `localhost:5173/` 
- **Booking App**: `localhost:5173/book` (proxied to servase-ui on port 3000)

## How It Works

### Development Setup
1. **Website (Vite)**: Runs on port **5173**
2. **servase-ui (React)**: Runs on port **3000**
3. **Proxy**: Vite proxies `/book` requests from port 5173 to port 3000

When you visit `http://localhost:5173/book`, Vite forwards the request to `http://localhost:3000` seamlessly.

## Configuration Files Changed

### 1. Website Vite Config
**File**: `/apps/servease-website/vite.config.js`

```javascript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/book': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/book/, ''),
        ws: true, // Enable WebSocket proxying
      },
    },
  },
})
```

### 2. servase-ui Port Configuration
**File**: `/apps/servase-ui/.env.local`

Added:
```bash
PORT=3000
```

### 3. All Booking Links Updated
All buttons/links now use `/book`:
- Home page: "Book a Service", service cards, "Download App", "Get Started Now"
- Services page: "Book Service Now"
- Navbar: "Download App" (desktop & mobile)

## Running the Apps

### Option 1: Manual (Two Terminals)

**Terminal 1 - Start servase-ui (MUST START FIRST):**
```bash
cd apps/servase-ui
PORT=3000 npm start
```

**Terminal 2 - Start website:**
```bash
cd apps/servease-website
npm run dev
```

### Option 2: Using Root Scripts

**Start servase-ui:**
```bash
npm run dev:ui
```

**Start website (in another terminal):**
```bash
npm run dev:website
```

### ⚠️ Important: Order Matters!
**Always start servase-ui FIRST** before the website, otherwise the proxy won't have anything to forward to.

## Testing

1. Visit `http://localhost:5173/` - should show the website
2. Click any "Book a Service" button
3. Should navigate to `http://localhost:5173/book` 
4. Should load the servase-ui booking application

## Troubleshooting

### Issue: `/book` shows 404 or blank page

**Solution**: Make sure servase-ui is running on port 3000
```bash
# Check if port 3000 is in use
lsof -i :3000

# If nothing, start servase-ui
cd apps/servase-ui
PORT=3000 npm start
```

### Issue: Proxy not working

**Solution**: Restart the website dev server after servase-ui is running
```bash
# In website terminal, press Ctrl+C to stop
# Then restart
npm run dev
```

### Issue: Port 3000 already in use

**Solution**: Find and kill the process using port 3000
```bash
lsof -i :3000
kill -9 <PID>
```

### Issue: Website runs but links don't work

**Solution**: Clear browser cache and hard refresh (Cmd+Shift+R on Mac)

## Production Deployment

For production, you'll need a reverse proxy (nginx/Apache) or a CDN configuration:

### Nginx Example
```nginx
server {
    listen 80;
    server_name www.serveaso.com;

    # Website root
    location / {
        root /var/www/servease-website/dist;
        try_files $uri $uri/ /index.html;
    }

    # Booking app
    location /book {
        alias /var/www/servase-ui/build;
        try_files $uri $uri/ /book/index.html;
    }
}
```

### Cloudflare/Vercel/Netlify
Use their rewrite/redirect rules:

**Vercel vercel.json:**
```json
{
  "rewrites": [
    { "source": "/book/:path*", "destination": "https://booking-app.vercel.app/:path*" },
    { "source": "/:path*", "destination": "https://website.vercel.app/:path*" }
  ]
}
```

## Development URLs Summary

| URL | Application | Port |
|-----|-------------|------|
| http://localhost:5173/ | Website | 5173 |
| http://localhost:5173/book | Booking (proxied) | 5173 → 3000 |
| http://localhost:3000/ | Booking (direct) | 3000 |

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│  Browser: localhost:5173                │
├─────────────────────────────────────────┤
│                                         │
│  GET /              → Website           │
│  GET /services      → Website           │
│  GET /book          → [Proxy] ────────┐ │
│                                       │ │
└───────────────────────────────────────┼─┘
                                        │
                ┌───────────────────────▼───┐
                │  servase-ui (Port 3000)   │
                │  Booking Application      │
                └───────────────────────────┘
```

## Quick Reference

**Start both apps:**
```bash
# Terminal 1
cd apps/servase-ui && PORT=3000 npm start

# Terminal 2  
cd apps/servease-website && npm run dev
```

**Stop apps:**
- Press `Ctrl+C` in each terminal

**Access website:**
- http://localhost:5173/

**Access booking:**
- http://localhost:5173/book (through proxy)
- http://localhost:3000/ (direct access)

## Next Steps

1. Test the proxy setup works locally
2. Update production deployment configuration
3. Set up environment-specific URLs
4. Add analytics tracking for booking conversions
5. Consider service worker for offline support
