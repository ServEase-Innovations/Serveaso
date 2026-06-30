# Provider Gender Preference - Quick Start Guide

## 🚀 Quick Deployment (5 Minutes)

### Step 1: Run Database Migration (1 min)
```bash
cd /Users/ronit/Desktop/serveaso/Serveaso-BE
npm run db:migrate
```

### Step 2: Restart Backend (1 min)
```bash
# If using PM2
pm2 restart payments-service

# OR if using docker
docker-compose restart payments
```

### Step 3: Test It Works (3 min)
```bash
# Check database column exists
psql -d serveaso -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'engagements' AND column_name = 'provider_gender_preference';"

# Expected output: provider_gender_preference
```

### Step 4: Deploy Frontend
```bash
# Mobile (iOS)
cd apps/servease-ios
# Follow your normal iOS deployment process

# Web
cd apps/servase-ui
npm run build
# Deploy build/ folder to your hosting
```

---

## ✅ Quick Test

### Test on Web UI
1. Open http://localhost:3000 (or your web URL)
2. Click "Book Service"
3. Select "One-time" booking
4. Pick date/time
5. **Look for "Provider Gender Preference" section**
6. Select "Male" or "Female"
7. Complete booking
8. Check logs: `tail -f logs/payments.log | grep "Gender Filter"`

### Test on Mobile
1. Open iOS app
2. Navigate to booking screen
3. Select "One-time" booking
4. Pick date/time  
5. **Look for gender preference options**
6. Select a preference
7. Complete booking

---

## 🎯 What to Expect

### When Customer Selects "Male"
- ✅ Engagement saved with `provider_gender_preference = 'Male'`
- ✅ Backend filters: `WHERE sp.gender = 'Male'`
- ✅ Only male providers receive notification
- ✅ Log shows: `[Gender Filter] Engagement XXX: filtering for Male providers`

### When Customer Selects "Female"
- ✅ Engagement saved with `provider_gender_preference = 'Female'`
- ✅ Backend filters: `WHERE sp.gender = 'Female'`
- ✅ Only female providers receive notification
- ✅ Log shows: `[Gender Filter] Engagement XXX: filtering for Female providers`

### When Customer Selects "No Preference"
- ✅ Engagement saved with `provider_gender_preference = 'No Preference'`
- ✅ No gender filtering applied
- ✅ All eligible providers receive notification
- ✅ Same behavior as before this feature

---

## 📁 Key Files Changed

| Platform | File | What Changed |
|----------|------|--------------|
| iOS | `apps/servease-ios/src/BookingDialog/BookingDialog.tsx` | Added gender UI |
| iOS | `apps/servease-ios/src/ServiceDialogs/ServiceBookingFlow.tsx` | Send to backend |
| Web | `apps/servase-ui/src/components/BookingDialog/BookingDialog.tsx` | Added gender UI |
| Web | `apps/servase-ui/src/components/ProviderDetails/ServiceBookingFlow.tsx` | Send to backend |
| Backend | `database/sql/106_provider_gender_preference.sql` | Migration |
| Backend | `services/payments/src/routes/v2/createEngagements.js` | Accept field |
| Backend | `services/payments/src/services/onDemandProviderBroadcast.js` | Filter providers |

---

## 🔍 Quick Verification

### Database Check
```sql
-- See recent bookings with gender preference
SELECT 
  engagement_id,
  provider_gender_preference,
  booking_type,
  created_at
FROM engagements
ORDER BY created_at DESC
LIMIT 5;
```

### Log Check
```bash
# See gender filtering in action
tail -20 logs/payments.log | grep -i gender
```

### Provider Check
```sql
-- How many providers per gender?
SELECT 
  gender,
  COUNT(*) as count
FROM serviceprovider
WHERE isactive = true
  AND housekeepingrole IN ('MAID', 'COOK')
GROUP BY gender;
```

---

## 🆘 Troubleshooting

### Problem: Gender preference not visible
**Solution:** Check if booking type is "One-time" (not Short-term or Monthly)

### Problem: Backend error "column does not exist"
**Solution:** Run migration: `npm run db:migrate`

### Problem: No providers found with gender filter
**Solution:** Check if providers have `gender` field populated in database

### Problem: Frontend shows but backend doesn't filter
**Solution:** 
1. Check backend logs for `[Gender Filter]` messages
2. Verify `provider_gender_preference` is in request payload
3. Restart backend service

---

## 📊 Quick Stats Query

```sql
-- Gender preference usage (last 7 days)
SELECT 
  provider_gender_preference,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as percentage
FROM engagements
WHERE created_at >= NOW() - INTERVAL '7 days'
  AND booking_type = 'ON_DEMAND'
GROUP BY provider_gender_preference
ORDER BY count DESC;
```

---

## 📞 Need Help?

1. Check logs: `tail -f logs/payments.log`
2. Check database: See SQL queries above
3. Review full docs: `COMPLETE_IMPLEMENTATION_SUMMARY.md`
4. Check code: See "Key Files Changed" above

---

## ✨ Feature Summary

- 🎯 **What:** Provider gender preference for on-demand bookings
- 👥 **Options:** Male, Female, No Preference
- 📱 **Platforms:** iOS app, Web UI
- 🔧 **Backend:** Automatic provider filtering
- 📊 **Default:** No Preference (non-intrusive)
- 🎨 **UI:** Only shows for one-time bookings

---

**Ready to go! 🚀**

All changes are complete and tested. Just run the migration and restart the backend!
