# GitHub Secrets for Tracking Service Deployment

To enable tracking service deployment via GitHub Actions, you need to add these secrets to your GitHub repository.

## 📍 Where to Add Secrets

Go to: **GitHub Repository** → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

---

## 🔐 Required Secrets for Tracking Service

### 1. **RENDER_DEPLOY_HOOK_TRACKING**

**What it is:** The Render deploy hook URL for the tracking service

**How to get it:**
1. Go to [Render Dashboard](https://dashboard.render.com/)
2. Select your **notifications** service (or create it if it doesn't exist)
3. Go to **Settings** → **Deploy Hook**
4. Copy the deploy hook URL

**Value format:**
```
https://api.render.com/deploy/srv-xxxxxxxxxxxxx?key=yyyyyyyyyyyy
```

**Add to GitHub:**
- Name: `RENDER_DEPLOY_HOOK_TRACKING`
- Secret: `https://api.render.com/deploy/srv-xxxxxxxxxxxxx?key=yyyyyyyyyyyy`

---

### 2. **RENDER_SERVICE_ID_TRACKING**

**What it is:** The Render service ID for the tracking service

**How to get it:**
1. From the deploy hook URL above, extract the service ID
2. It's the part after `/deploy/` and before `?key=`
3. Format: `srv-xxxxxxxxxxxxx`

**OR:**
1. Go to Render Dashboard → Select your notifications service
2. Look at the URL in your browser
3. Format: `https://dashboard.render.com/web/srv-xxxxxxxxxxxxx`

**Value format:**
```
srv-xxxxxxxxxxxxx
```

**Add to GitHub:**
- Name: `RENDER_SERVICE_ID_TRACKING`
- Secret: `srv-xxxxxxxxxxxxx`

---

## 🔐 Optional: Production Secrets (for EC2)

If you want to deploy tracking to production (EC2), add these:

### 3. **PROD_ENV_TRACKING** (Optional)

**What it is:** Multi-line environment variables for production deployment

**Value format:**
```
NODE_ENV=production
PORT=5007
POSTGRES_HOST=your-prod-postgres-host
POSTGRES_PORT=5432
POSTGRES_DATABASE=serveaso
POSTGRES_USER=your-prod-user
POSTGRES_PASSWORD=your-prod-password
REDIS_HOST=your-redis-host
REDIS_PORT=6379
REDIS_PASSWORD=your-redis-password
GOOGLE_MAPS_API_KEY=your-google-maps-key
JWT_SECRET=your-jwt-secret
ENCRYPTION_KEY=your-encryption-key
```

**Add to GitHub:**
- Name: `PROD_ENV_TRACKING`
- Secret: (paste the multi-line content above)

---

### 4. **EC2_DEPLOY_PATH_TRACKING** (Optional)

**What it is:** Custom EC2 deployment path (defaults to `/home/ubuntu/tracking`)

**Default value:** `/home/ubuntu/tracking`

**Only add if you want a different path:**
- Name: `EC2_DEPLOY_PATH_TRACKING`
- Secret: `/your/custom/path/tracking`

---

## ✅ Summary: Minimum Required Secrets

To deploy tracking via GitHub Actions, you **must** add at least these 2 secrets:

1. ✅ `RENDER_DEPLOY_HOOK_TRACKING`
2. ✅ `RENDER_SERVICE_ID_TRACKING`

The optional secrets (3 & 4) are only needed if you plan to deploy to production EC2.

---

## 🚀 How to Deploy After Adding Secrets

### Via GitHub Actions UI:

1. Go to: **Actions** → **Deploy Backend**
2. Click **"Run workflow"**
3. Select:
   - **environment:** `dev`
   - **service:** `tracking` (or `all` to deploy everything)
   - **run_migrations:** `true` (recommended first time)
   - **wait_for_render:** `true` (to see logs)
4. Click **"Run workflow"**

### The workflow will:
1. ✅ Run database migrations (creates `tracking_sessions` table)
2. ✅ Push tracking service code to notifications submodule
3. ✅ Trigger Render deployment via deploy hook
4. ✅ Wait for deployment to complete (if `wait_for_render: true`)
5. ✅ Run integration tests (if enabled)
6. ✅ Send deployment notification email

---

## 📝 Example: Getting the Deploy Hook

```bash
# Your Render deploy hook will look like:
https://api.render.com/deploy/srv-cq6h4p5g1b2c73e4a5d0?key=AbCdEfGhIjKlMnOpQrSt

# Extract the service ID:
srv-cq6h4p5g1b2c73e4a5d0

# Add to GitHub:
RENDER_DEPLOY_HOOK_TRACKING = https://api.render.com/deploy/srv-cq6h4p5g1b2c73e4a5d0?key=AbCdEfGhIjKlMnOpQrSt
RENDER_SERVICE_ID_TRACKING = srv-cq6h4p5g1b2c73e4a5d0
```

---

## 🔍 Verification

After adding the secrets, you can verify they're set correctly:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. You should see:
   - `RENDER_DEPLOY_HOOK_TRACKING` ✅
   - `RENDER_SERVICE_ID_TRACKING` ✅

---

## ⚠️ Important Notes

1. **Tracking service path:** The service is located at `services/notifications/tracking/`, not at the root of the notifications repo
2. **Build command:** The workflow will use `cd tracking && npm install` as configured in `services.json`
3. **Migrations:** The first deployment should have `run_migrations: true` to create the database table
4. **Render auto-deploy:** If you have Render auto-deploy enabled on the notifications repo, it will deploy automatically when you push. The GitHub Actions workflow provides additional control and monitoring.

---

## 🆘 Troubleshooting

**If deployment fails:**

1. Check the GitHub Actions logs for error messages
2. Verify the deploy hook URL is correct (test it with `curl -X POST <hook-url>`)
3. Ensure the service ID matches your Render service
4. Check that the notifications submodule is up to date
5. Verify database migrations ran successfully

**Common issues:**

- ❌ **"Service not found"**: Service ID is incorrect
- ❌ **"Unauthorized"**: Deploy hook key is invalid
- ❌ **"Build failed"**: Check Render logs for build errors
- ❌ **"Database error"**: Run migrations or check database credentials

---

Need help? Check the main deployment docs in `docs/DEPLOYMENT.md`
