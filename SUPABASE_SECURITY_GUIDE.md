# Supabase Security Fix - RLS Critical Issues

## 🚨 CRITICAL: Immediate Action Required

Your Supabase database has **Row Level Security (RLS) disabled** on **all public tables**, exposing:

- ✋ **Passwords** (plaintext or hashed)
- ✋ **Payment information**
- ✋ **Personal data** (PII)
- ✋ **Session tokens**
- ✋ **Financial transactions**

---

## 📊 Impact Assessment

### **Current Exposure:**

| Risk Level | Tables Affected | Data Exposed |
|------------|----------------|--------------|
| **CRITICAL** | `user_credentials`, `users` | Passwords |
| **CRITICAL** | `payments`, `wallet_transactions` | Payment data, card info |
| **HIGH** | `customer`, `serviceprovider`, `kyc` | PII, documents |
| **HIGH** | `tracking_sessions` | Session IDs, location |
| **MEDIUM** | All other tables (67 total) | Business data |

### **Who Can Access:**

Currently, **anyone with your Supabase URL** can:
- Read all user passwords
- View all payment transactions
- Access customer personal information
- See provider KYC documents
- Read session tokens

---

## ⚡ Quick Fix (5 Minutes)

### Step 1: Run the RLS Fix Script

1. **Open Supabase Dashboard:**
   ```
   https://supabase.com/dashboard
   ```

2. **Go to SQL Editor:**
   ```
   Your Project → SQL Editor → New Query
   ```

3. **Copy the script:**
   - Open: `SUPABASE_RLS_FIX.sql` (created in your repo)
   - Copy entire content

4. **Paste and Run:**
   - Paste into SQL Editor
   - Click **"Run"** or press `Cmd+Enter`
   - Wait for completion (few seconds)

5. **Verify:**
   ```sql
   SELECT 
       tablename,
       rowsecurity as rls_enabled
   FROM pg_tables
   WHERE schemaname = 'public'
   ORDER BY tablename;
   ```
   All tables should show `rls_enabled = true`

---

## 🔐 Understanding the Fix

### What the Script Does:

1. **Enables RLS on all tables**
   ```sql
   ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
   ```

2. **Creates policies for service role**
   - Allows your backend services full access
   - Blocks anonymous/public access
   - Blocks unauthenticated requests

### How It Works:

```
┌─────────────────┐
│  Frontend App   │
│  (ANON_KEY)     │ ───X BLOCKED
└─────────────────┘

┌─────────────────┐
│  Backend API    │
│ (SERVICE_ROLE)  │ ───✓ ALLOWED (Full Access)
└─────────────────┘

┌─────────────────┐
│  Public/Anon    │ ───X BLOCKED
└─────────────────┘
```

---

## 🔑 API Keys Configuration

### You Have 2 Keys:

1. **ANON_KEY** (Public - Safe to expose)
   - Used in frontend apps
   - Respects RLS policies
   - Limited access

2. **SERVICE_ROLE_KEY** (Secret - NEVER expose)
   - Bypasses RLS
   - Full database access
   - Backend services only

### Current vs Secure Setup:

#### ❌ BEFORE (Insecure):
```javascript
// Frontend using ANON_KEY
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
// Problem: No RLS = Anyone can read passwords!
```

#### ✅ AFTER (Secure):
```javascript
// Frontend using ANON_KEY
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
// Good: RLS enabled = Blocked unless policy allows

// Backend using SERVICE_ROLE_KEY
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
// Good: Backend has full access for authorized operations
```

---

## 🛠️ Configuration Check

### Step 1: Verify Your Keys

Check which key you're using in each service:

```bash
# Backend services - Should use SERVICE_ROLE_KEY
grep -r "SUPABASE.*KEY" services/*/src/**/*.{js,ts}

# Frontend apps - Should use ANON_KEY
grep -r "SUPABASE.*KEY" apps/*/src/**/*.{js,ts,tsx}
```

### Step 2: Update Configuration

**Backend (.env files):**
```bash
# Use SERVICE_ROLE_KEY (from Supabase Dashboard → Settings → API)
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...very_long_key
```

**Frontend (.env files):**
```bash
# Use ANON_KEY (safe to expose)
SUPABASE_ANON_KEY=eyJhbGc...shorter_key
```

---

## 📝 Testing After Fix

### Test 1: Verify RLS is Enabled

```sql
-- Run in Supabase SQL Editor
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND rowsecurity = false;

-- Should return 0 rows (empty result)
```

### Test 2: Test Anonymous Access (Should Fail)

```javascript
// This should FAIL (no policy for anon role)
const { data, error } = await supabase
  .from('users')
  .select('*')
  
// Expected: error "new row violates row-level security policy"
```

### Test 3: Test Backend Access (Should Work)

```javascript
// Using SERVICE_ROLE_KEY - should work
const { data, error } = await supabaseAdmin
  .from('users')
  .select('*')
  
// Expected: data returned successfully
```

---

## 🔍 Common Issues & Solutions

### Issue 1: "Backend can't access database"

**Symptom:** Your backend API returns errors after enabling RLS

**Cause:** Backend is using ANON_KEY instead of SERVICE_ROLE_KEY

**Solution:**
```bash
# Check your backend .env
echo $SUPABASE_KEY

# Should be SERVICE_ROLE_KEY (very long, starts with eyJ...)
# If it's ANON_KEY, update to SERVICE_ROLE_KEY
```

---

### Issue 2: "Frontend needs direct database access"

**Symptom:** You want frontend to query database directly

**Solution:** Create specific RLS policies

```sql
-- Example: Allow users to read their own data
CREATE POLICY "Users can read own data" ON public.customer
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Example: Allow public read of service providers
CREATE POLICY "Public can view providers" ON public.serviceprovider
FOR SELECT
TO anon, authenticated
USING (status = 'APPROVED');
```

---

### Issue 3: "Migration/seeding scripts fail"

**Symptom:** Database migrations or seeding fails with RLS errors

**Solution:** Use SERVICE_ROLE_KEY for migrations

```javascript
// migrations/run.js
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY // Use admin key
)
```

---

## 🎯 Best Practices Going Forward

### ✅ DO:

1. **Always use SERVICE_ROLE_KEY in backend**
   - Node.js services
   - API endpoints
   - Background jobs
   - Migrations

2. **Always use ANON_KEY in frontend**
   - React apps
   - Mobile apps
   - Public-facing sites

3. **Create specific RLS policies** when needed
   - User can read own data
   - Public can read approved content
   - Admins can read everything

4. **Test RLS policies thoroughly**
   - Test as authenticated user
   - Test as anonymous user
   - Test as admin

5. **Monitor Supabase dashboard**
   - Check for security alerts
   - Review database linter regularly

### ❌ DON'T:

1. **Never expose SERVICE_ROLE_KEY**
   - Don't commit to git
   - Don't use in frontend
   - Don't log or display

2. **Don't disable RLS** once enabled
   - Creates security holes
   - Exposes sensitive data

3. **Don't use overly permissive policies**
   - Avoid `USING (true)` for public roles
   - Be specific about what's allowed

---

## 📊 Architecture Recommendation

### Current Architecture (After Fix):

```
┌─────────────────────────────────────────┐
│           Frontend Apps                 │
│    (iOS, Web - using ANON_KEY)         │
└──────────────┬──────────────────────────┘
               │
               │ API Calls
               ▼
┌─────────────────────────────────────────┐
│         Backend Services                │
│   (Payments, Providers, Utils, etc.)   │
│     (using SERVICE_ROLE_KEY)           │
└──────────────┬──────────────────────────┘
               │
               │ Direct DB Access
               ▼
┌─────────────────────────────────────────┐
│         Supabase PostgreSQL            │
│          (RLS Enabled ✓)               │
└─────────────────────────────────────────┘
```

This is **secure** because:
- Frontend never directly queries sensitive data
- All access goes through your backend API
- Backend authenticates and authorizes
- RLS provides defense in depth

---

## 🚀 Deployment Checklist

Before deploying to production:

- [ ] RLS enabled on all tables
- [ ] Service role policies created
- [ ] Backend uses SERVICE_ROLE_KEY
- [ ] Frontend uses ANON_KEY
- [ ] Never commit SERVICE_ROLE_KEY to git
- [ ] Test all API endpoints
- [ ] Verify password tables are protected
- [ ] Verify payment tables are protected
- [ ] Check Supabase database linter (0 errors)
- [ ] Monitor logs for RLS errors

---

## 📚 Resources

- **Supabase RLS Docs:** https://supabase.com/docs/guides/database/postgres/row-level-security
- **Database Linter:** https://supabase.com/docs/guides/database/database-linter
- **API Keys:** https://supabase.com/docs/guides/api/api-keys
- **Your SQL Fix:** `SUPABASE_RLS_FIX.sql`

---

## 🆘 Need Help?

1. **Check Supabase Dashboard:**
   - Dashboard → Database → Linter
   - Should show 0 errors after fix

2. **Test in Development First:**
   - Never test security changes directly in production
   - Use a staging database

3. **Rollback if needed:**
   ```sql
   -- To disable RLS (temporary, for testing only):
   ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
   ```

---

**Status:** RLS fix script created and ready to run  
**Priority:** CRITICAL - Run immediately  
**Est. Time:** 5 minutes  
**Risk:** Low (script only enables security, doesn't change data)

---

**Last Updated:** August 16, 2026
