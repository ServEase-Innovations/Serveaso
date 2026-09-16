#!/usr/bin/env bash
# Quick test for a single Render deploy hook
# Usage: ./check-single-hook.sh "https://api.render.com/deploy/srv-xxx?key=yyy"

set -euo pipefail

HOOK_URL="${1:?Deploy hook URL required}"

echo "Testing deploy hook..."
echo "URL: ${HOOK_URL:0:50}..." # Show first 50 chars only
echo ""

# Check format
if [[ ! "${HOOK_URL}" =~ ^https://api\.render\.com/deploy/srv-[a-zA-Z0-9]+\?key=[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ INVALID FORMAT"
    echo ""
    echo "Expected format:"
    echo "https://api.render.com/deploy/srv-xxxxxxxxxxxxx?key=yyyyyyyyyyyyy"
    echo ""
    echo "Common issues:"
    echo "- Extra spaces before/after"
    echo "- Missing 'https://'"
    echo "- Missing '?key=' parameter"
    echo "- Quotes around the URL"
    echo "- Newlines in the URL"
    exit 1
fi

# Test POST request
echo "Sending POST request..."
http_code=$(curl -sS -o /tmp/render-response.txt -w "%{http_code}" -X POST "${HOOK_URL}" 2>&1)

echo "HTTP Code: ${http_code}"
echo ""
echo "Response:"
cat /tmp/render-response.txt 2>/dev/null || echo "(no response body)"
echo ""

if [[ "${http_code}" -ge 200 && "${http_code}" -lt 300 ]]; then
    echo "✅ SUCCESS - Deploy hook is working!"
    exit 0
elif [[ "${http_code}" == "000" ]]; then
    echo "❌ FAILED - Could not resolve host"
    echo ""
    echo "This means the URL is malformed. Check for:"
    echo "1. Hidden characters (copy-paste from a plain text editor)"
    echo "2. Extra spaces or newlines"
    echo "3. URL encoding issues"
    echo ""
    echo "Try copying the hook again from Render dashboard"
    exit 1
else
    echo "⚠️  WARNING - Unexpected HTTP code"
    echo ""
    echo "Possible issues:"
    echo "- Invalid API key in URL"
    echo "- Service is paused or deleted"
    echo "- Render API is down"
    exit 1
fi
