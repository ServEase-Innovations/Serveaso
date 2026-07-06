# ETA & Route Tracking - Deployment Checklist

## Pre-Deployment

### 1. Database Preparation ⚠️ CRITICAL

- [ ] **Check engagement coordinates**
  ```bash
  psql $DATABASE_URL -f database/sql/check_engagement_coordinates.sql
  ```

- [ ] **Verify count of missing coordinates**
  ```sql
  SELECT COUNT(*) FROM engagements 
  WHERE active = true 
  AND (latitude IS NULL OR longitude IS NULL);
  ```
  
- [ ] **If count > 0, choose migration strategy**:
  - [ ] Option A: Use customer home addresses (quick, less accurate)
  - [ ] Option B: Manual update for critical engagements
  - [ ] Option C: Geocode addresses (best, requires API)

- [ ] **Run selected migration**
- [ ] **Verify coordinates are valid**
  ```sql
  SELECT engagement_id, latitude, longitude 
  FROM engagements 
  WHERE latitude IS NOT NULL 
  AND (latitude < -90 OR latitude > 90 OR longitude < -180 OR longitude > 180);
  ```

### 2. Google Cloud Setup

- [ ] **Enable Required APIs**:
  - [ ] Maps JavaScript API
  - [ ] Directions API
  - [ ] Geometry Library

- [ ] **Create API Key** (or use existing)
- [ ] **Configure API Key Restrictions**:
  - [ ] HTTP referrers: `https://servease-innovation.netlify.app/*`
  - [ ] API restrictions: Maps JavaScript, Directions, Geometry
  
- [ ] **Set up Billing Alert**:
  - [ ] Alert at 80% of free tier (32,000 requests)
  - [ ] Alert at 100% of free tier (40,000 requests)

### 3. Environment Configuration

#### Backend Environment
- [ ] Update `services/notifications/tracking/.env`:
  ```bash
  GOOGLE_MAPS_API_KEY=your_key_here
  ETA_CACHE_TTL=120
  ETA_CALCULATION_INTERVAL=120000
  LOCATION_UPDATE_RATE_LIMIT=15000
  ```

#### Frontend Environment  
- [ ] Update `apps/servase-ui/.env.local`:
  ```bash
  REACT_APP_GOOGLE_MAPS_API_KEY=your_key_here
  REACT_APP_TRACKING_API_URL=https://notifications-mjdp.onrender.com
  ```

### 4. Code Review

- [ ] **Backend Changes**:
  - [ ] `trackingRoutes.js` - calculate-eta endpoint
  - [ ] `trackingAvailabilityService.js` - lat/lng fetch
  
- [ ] **Frontend Changes**:
  - [ ] `useETAPolling.ts` - new hook
  - [ ] `TrackingMapView.tsx` - polyline display
  - [ ] `trackingService.ts` - calculateETA function

- [ ] **Run linter**:
  ```bash
  cd apps/servase-ui && npm run lint
  ```

### 5. Testing

- [ ] **Backend Testing**:
  ```bash
  ./test-eta-calculation.sh 353 123
  ```

- [ ] **Frontend Testing**:
  - [ ] Provider location updates display
  - [ ] Route line displays on map
  - [ ] ETA calculation works
  - [ ] ETA countdown functions
  - [ ] Map markers render correctly

- [ ] **Integration Testing**:
  - [ ] End-to-end tracking flow
  - [ ] Multiple concurrent sessions
  - [ ] WebSocket connection stability
  - [ ] Polling fallback works

---

## Deployment Steps

### Step 1: Backup

- [ ] **Backup Database**:
  ```bash
  pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql
  ```

- [ ] **Backup Current Frontend Build**:
  ```bash
  cd apps/servase-ui && cp -r build build_backup_$(date +%Y%m%d)
  ```

### Step 2: Deploy Backend

- [ ] **Pull latest code on server**:
  ```bash
  git pull origin main
  ```

- [ ] **Update environment variables** on Render/server

- [ ] **Restart tracking service**:
  ```bash
  # On Render: Use dashboard to restart
  # Or via CLI: render services restart notifications
  ```

- [ ] **Verify service is running**:
  ```bash
  curl https://notifications-mjdp.onrender.com/api/tracking/health
  ```

### Step 3: Deploy Frontend

- [ ] **Build frontend**:
  ```bash
  cd apps/servase-ui
  npm run build
  ```

- [ ] **Test build locally**:
  ```bash
  npx serve -s build
  ```

- [ ] **Deploy to Netlify**:
  ```bash
  # Push to main branch (auto-deploys)
  git push origin main
  
  # Or manual deploy:
  netlify deploy --prod
  ```

- [ ] **Wait for deployment** (check Netlify dashboard)

### Step 4: Smoke Testing

- [ ] **Test tracking endpoint**:
  ```bash
  curl https://notifications-mjdp.onrender.com/api/tracking/availability/353
  ```

- [ ] **Test calculate-eta endpoint**:
  ```bash
  curl -X POST https://notifications-mjdp.onrender.com/api/tracking/calculate-eta \
    -H "Content-Type: application/json" \
    -d '{"engagement_id": 353}'
  ```

- [ ] **Test frontend**:
  - [ ] Open https://servease-innovation.netlify.app
  - [ ] Navigate to bookings
  - [ ] Click "Track Provider"
  - [ ] Verify map loads
  - [ ] Verify markers display
  - [ ] Verify route line shows
  - [ ] Verify ETA displays

---

## Post-Deployment

### Immediate Monitoring (First Hour)

- [ ] **Check Backend Logs**:
  ```bash
  # On Render: View logs in dashboard
  # Look for errors in ETA calculation
  ```

- [ ] **Monitor Frontend Console**:
  - [ ] Check for JavaScript errors
  - [ ] Verify API calls succeed
  - [ ] Check network tab for failed requests

- [ ] **Test with Real Engagement**:
  - [ ] Have provider start journey
  - [ ] Customer tracks provider
  - [ ] Verify ETA accuracy

### First Day Monitoring

- [ ] **Google Maps API Usage**:
  - [ ] Check GCP Console → APIs & Services → Dashboard
  - [ ] Verify requests are within quota
  - [ ] Check for any API errors

- [ ] **Database Performance**:
  ```sql
  -- Check query performance
  SELECT * FROM pg_stat_statements 
  WHERE query LIKE '%engagements%' 
  ORDER BY total_time DESC LIMIT 10;
  ```

- [ ] **Redis Memory Usage**:
  ```bash
  redis-cli INFO memory
  ```

- [ ] **User Feedback**:
  - [ ] Monitor support tickets
  - [ ] Check for tracking-related issues

### First Week Monitoring

- [ ] **ETA Accuracy Metrics**:
  ```sql
  -- Compare predicted vs actual arrival times
  SELECT 
    engagement_id,
    journey_started_at,
    arrived_at,
    arrived_at - journey_started_at as actual_duration
  FROM engagement_tracking_status
  WHERE arrived_at IS NOT NULL
  ORDER BY journey_started_at DESC
  LIMIT 20;
  ```

- [ ] **Tracking Adoption Rate**:
  ```sql
  SELECT 
    COUNT(DISTINCT engagement_id) as tracked_engagements,
    (SELECT COUNT(*) FROM engagements WHERE active = true) as total_engagements,
    ROUND(100.0 * COUNT(DISTINCT engagement_id) / 
      (SELECT COUNT(*) FROM engagements WHERE active = true), 2) as adoption_rate
  FROM tracking_sessions
  WHERE started_at > NOW() - INTERVAL '7 days';
  ```

- [ ] **API Cost Analysis**:
  - [ ] Review Google Cloud billing
  - [ ] Calculate cost per tracking session
  - [ ] Adjust polling intervals if needed

---

## Rollback Plan

### If Critical Issue Occurs

1. **Identify Issue Severity**:
   - Critical: Complete service outage
   - High: Feature broken for all users
   - Medium: Feature broken for some users
   - Low: Minor UI/UX issues

2. **For Critical/High Issues**:

   **Backend Rollback**:
   ```bash
   # Revert to previous commit
   git revert HEAD
   git push origin main
   
   # Or rollback to specific commit
   git reset --hard <previous_commit_hash>
   git push origin main --force
   
   # Restart service
   ```

   **Frontend Rollback**:
   ```bash
   # Netlify: Use dashboard to rollback to previous deployment
   # Or via CLI:
   netlify rollback
   ```

3. **For Medium/Low Issues**:
   - Document issue
   - Create hotfix branch
   - Test fix thoroughly
   - Deploy fix

---

## Success Criteria

After deployment, verify these metrics:

### Technical Success
- [ ] ✅ Zero 500 errors in tracking endpoints
- [ ] ✅ Provider location updates every 15s
- [ ] ✅ ETA calculates successfully (>95% success rate)
- [ ] ✅ Route displays on map
- [ ] ✅ Map loads within 3 seconds
- [ ] ✅ No memory leaks (check Redis & browser)

### Business Success
- [ ] ✅ >30% of eligible bookings use tracking
- [ ] ✅ <10% error rate in tracking sessions
- [ ] ✅ ETA accuracy within ±5 minutes
- [ ] ✅ Zero critical support tickets
- [ ] ✅ Positive user feedback

---

## Known Issues & Workarounds

### Issue 1: Missing Engagement Coordinates
**Symptom**: "Destination coordinates not available" error  
**Workaround**: Update engagement manually  
**Long-term Fix**: Add coordinate picker to booking form

### Issue 2: Google Maps API Rate Limit
**Symptom**: Fallback to straight-line ETA  
**Workaround**: Increase cache TTL to 5 minutes  
**Long-term Fix**: Upgrade to premium API tier

### Issue 3: WebSocket Disconnections
**Symptom**: Tracking stops updating  
**Workaround**: Polling fallback handles it  
**Long-term Fix**: Improve reconnection logic

---

## Communication Plan

### Before Deployment
- [ ] Notify team via Slack/email
- [ ] Schedule deployment window
- [ ] Prepare rollback plan

### During Deployment
- [ ] Post status updates
- [ ] Monitor health metrics
- [ ] Be available for issues

### After Deployment
- [ ] Announce successful deployment
- [ ] Share documentation links
- [ ] Collect feedback

---

## Documentation Checklist

- [x] Technical documentation (ETA_AND_ROUTE_DISPLAY_COMPLETE.md)
- [x] Implementation summary (ETA_IMPLEMENTATION_SUMMARY.md)
- [x] Quick start guide (QUICK_START_ETA_TRACKING.md)
- [x] Changes summary (TRACKING_CHANGES_SUMMARY.md)
- [x] This deployment checklist
- [ ] Update main README.md with tracking features
- [ ] Update API documentation
- [ ] Create user-facing help docs

---

## Final Verification

Before marking deployment complete:

- [ ] All checklist items completed
- [ ] No critical errors in logs
- [ ] Test with at least 3 real engagements
- [ ] Team trained on new features
- [ ] Support docs updated
- [ ] Monitoring dashboards configured

---

## Support Contacts

- **Backend Issues**: [Backend Team Lead]
- **Frontend Issues**: [Frontend Team Lead]
- **Database Issues**: [DBA]
- **DevOps Issues**: [DevOps Lead]
- **Product Questions**: [Product Manager]

---

## Deployment Sign-off

- [ ] **Backend Lead**: _______________ Date: ___/___/___
- [ ] **Frontend Lead**: _______________ Date: ___/___/___
- [ ] **QA Lead**: _______________ Date: ___/___/___
- [ ] **Product Manager**: _______________ Date: ___/___/___
- [ ] **Engineering Manager**: _______________ Date: ___/___/___

---

**Deployment Date**: _______________  
**Deployed By**: _______________  
**Status**: ⬜ In Progress | ⬜ Complete | ⬜ Rolled Back

---

Good luck with the deployment! 🚀
