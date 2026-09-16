# Render Deploy Debugging Guide

## 🔍 Debug Logging Added

I've added comprehensive debug logging to help identify deploy hook issues.

### What's Been Added:

#### 1. **Workflow-Level Debug** (`.github/workflows/deploy-backend.yml`)

Now shows:
- ✅ Whether secret is set or empty
- ✅ Deploy hook format (with key masked)
- ✅ Hook URL length (should be ~100-150 characters)
- ✅ Service ID extracted from hook
- ✅ Common issues (trailing spaces, wrong format, etc.)

#### 2. **Script-Level Debug** (`.github/scripts/render-deploy.sh`)

Now shows:
- ✅ Hook URL format (with key masked)
- ✅ Whitespace detection and trimming
- ✅ URL format validation
- ✅ Host resolution check
- ✅ Detailed curl error messages
- ✅ curl exit codes

---

## 📊 What You'll See in Logs

### ✅ Success (Normal Flow):

```
🔍 Debug Info for providers:
Hook URL format: https://api.render.com/deploy/srv-xxxxx?key=***MASKED***
Hook length: 127 characters
Extracted Service ID from hook: srv-cq45r0btq21c73cshpr0
Final Service ID: srv-cq45r0btq21c73cshpr0
Service Path: services/providers
✅ Configuration validated successfully

🔍 Debug: Deploy Hook URL: https://api.render.com/deploy/srv-xxxxx?key=***MASKED***
🔍 Debug: Hook URL length: 127 characters
🔍 Debug: Attempting to call Render API...
🔍 Trying POST request...
POST https://api.render.com/deploy/srv-xxxxx → HTTP 200 (curl exit code: 0)
{"deploy":{"id":"dep-xxxxx"}}
```

---

### ❌ Error: Secret Not Set

```
🔍 Debug Info for providers:
::error::❌ RENDER_DEPLOY_HOOK_PROVIDERS is NOT SET or EMPTY
::error::Please set this secret in GitHub: Settings → Secrets → Actions → RENDER_DEPLOY_HOOK_PROVIDERS
```

---

### ❌ Error: Wrong Format

```
🔍 Debug Info for providers:
Hook URL format: http://wrong-url.com?key=***MASKED***
::error::❌ Deploy hook does not start with 'https://'
::error::Expected format: https://api.render.com/deploy/srv-xxxxx?key=yyyyy
```

---

### ❌ Error: Whitespace Issues

```
🔍 Debug Info for providers:
::warning::⚠️  Deploy hook has trailing whitespace
Hook URL format: https://api.render.com/deploy/srv-xxxxx?key=***MASKED***
...
```

---

### ❌ Error: Cannot Resolve Host

```
🔍 Debug: Attempting to call Render API...
🔍 Debug: Host check: api.render.com
🔍 Trying POST request...
POST https://api.render.com/deploy/srv-xxxxx → HTTP 000 (curl exit code: 6)
::error::❌ curl failed with exit code 6
🔍 Debug: curl error details:
* Could not resolve host: api.render.com
```

**This means:** The URL has hidden characters or is malformed.

---

## 🎯 Next Steps After Seeing Logs

### If you see "NOT SET or EMPTY":
1. The secret doesn't exist in GitHub
2. Go to: **Repo → Settings → Secrets → Actions**
3. Add the missing secret

### If you see "trailing whitespace":
1. Copy deploy hook from Render again
2. Paste into a plain text editor first
3. Make sure there's no space/newline at the end
4. Copy from text editor to GitHub secret

### If you see "does not start with https://":
1. The URL is completely wrong
2. Go to Render dashboard
3. Copy the **Deploy Hook** (not API key, not service URL)
4. Format: `https://api.render.com/deploy/srv-xxxxx?key=yyyyy`

### If you see "curl exit code 6" (Could not resolve):
1. Hidden characters in the URL
2. Copy hook to plain text editor (TextEdit, Notepad)
3. Check for weird characters
4. Re-copy and paste into GitHub secret

### If you see "curl exit code 7" (Connection refused):
1. Check if Render is down: https://status.render.com
2. Verify the service exists in Render dashboard
3. Try regenerating the deploy hook

---

## 🧪 Testing Before Pushing

Use the test scripts created for you:

### Test a single hook:
```bash
cd /Users/ronit/Desktop/serveaso/Serveaso-BE
chmod +x check-single-hook.sh

# Paste your actual deploy hook URL
./check-single-hook.sh "https://api.render.com/deploy/srv-xxxxx?key=yyyyy"
```

This will tell you immediately if the hook works.

---

## 📝 Common curl Exit Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 0 | Success | ✅ All good! |
| 6 | Could not resolve host | URL has hidden characters or typos |
| 7 | Failed to connect | Service doesn't exist or Render is down |
| 28 | Timeout | Network issue or Render is slow |
| 35 | SSL error | Certificate issue (rare) |
| 52 | Empty response | Service exists but not responding |

---

## 🔧 Quick Fix Checklist

Before re-running the workflow:

- [ ] Copied deploy hook from Render dashboard
- [ ] Pasted into plain text editor first
- [ ] No spaces or newlines before/after URL
- [ ] URL starts with `https://api.render.com/deploy/`
- [ ] URL contains `srv-` followed by alphanumeric ID
- [ ] URL contains `?key=` followed by key
- [ ] Pasted into GitHub secret (no quotes)
- [ ] Saved the secret

---

## 🎬 How to Use Debug Logs

1. **Commit these changes:**
   ```bash
   git add .github/workflows/deploy-backend.yml .github/scripts/render-deploy.sh
   git commit -m "Add debug logging for Render deploy hooks"
   git push
   ```

2. **Re-run the workflow:**
   - Go to Actions tab
   - Select "Deploy Backend"
   - Click "Run workflow"
   - Select service (or all)

3. **Check the logs:**
   - Click on the running workflow
   - Expand "Render — resolve hook and service id (dev)"
   - Look for the 🔍 debug messages

4. **Share the debug output** if still having issues

---

## 💡 Pro Tips

### Use Render API Instead
If deploy hooks keep failing, use Render API (more reliable):

1. Get Render API Key:
   ```
   Render Dashboard → Account Settings → API Keys
   ```

2. Add to GitHub Secrets:
   ```
   RENDER_API_KEY=rnd_xxxxxxxxxxxxx
   ```

3. Get each service ID:
   ```
   Render Dashboard → Service → Settings → Service ID
   ```

4. Add each to GitHub Secrets:
   ```
   RENDER_SERVICE_ID_PAYMENTS=srv-xxxxx
   RENDER_SERVICE_ID_PROVIDERS=srv-xxxxx
   ...
   ```

The workflow will automatically prefer API over hooks if both are set.

---

## 📞 Still Stuck?

After running with debug logs, share:
1. The full output of "Render — resolve hook and service id" step
2. The service name that's failing
3. Any 🔍 debug messages you see

This will help pinpoint the exact issue!

---

**Last Updated:** August 16, 2026  
**Status:** Debug logging active
