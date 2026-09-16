#!/usr/bin/env bash
# Test Render Deploy Hooks
# Usage: ./test-deploy-hooks.sh

set -euo pipefail

echo "🔍 Testing Render Deploy Hooks..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_hook() {
    local service="$1"
    local hook_url="$2"
    
    echo -n "Testing ${service}... "
    
    # Validate URL format
    if [[ ! "${hook_url}" =~ ^https://api\.render\.com/deploy/srv-[a-zA-Z0-9]+\?key=[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}INVALID FORMAT${NC}"
        echo "  Expected: https://api.render.com/deploy/srv-xxxxx?key=yyyyy"
        echo "  Got: ${hook_url}"
        return 1
    fi
    
    # Test with curl
    local http_code
    http_code=$(curl -sS -o /tmp/hook-test.txt -w "%{http_code}" -X POST "${hook_url}" 2>&1)
    
    if [[ "${http_code}" -ge 200 && "${http_code}" -lt 300 ]]; then
        echo -e "${GREEN}✓ OK${NC} (HTTP ${http_code})"
        return 0
    elif [[ "${http_code}" == "000" ]]; then
        echo -e "${RED}✗ FAILED${NC} (Could not resolve host)"
        echo "  This usually means the URL is malformed or has invalid characters"
        cat /tmp/hook-test.txt 2>/dev/null || true
        return 1
    else
        echo -e "${YELLOW}⚠ WARNING${NC} (HTTP ${http_code})"
        cat /tmp/hook-test.txt 2>/dev/null || true
        return 1
    fi
}

# Read hooks from user input
echo "Please paste your deploy hook URLs:"
echo "(Format: SERVICE_NAME=https://api.render.com/deploy/srv-xxx?key=yyy)"
echo "(Press Ctrl+D when done)"
echo ""

declare -A hooks

while IFS='=' read -r service url; do
    # Skip empty lines and comments
    [[ -z "${service}" || "${service}" =~ ^# ]] && continue
    
    # Remove whitespace
    service=$(echo "${service}" | xargs)
    url=$(echo "${url}" | xargs)
    
    hooks["${service}"]="${url}"
done

echo ""
echo "======================================"
echo "Testing ${#hooks[@]} deploy hooks..."
echo "======================================"
echo ""

passed=0
failed=0

for service in "${!hooks[@]}"; do
    if test_hook "${service}" "${hooks[${service}]}"; then
        ((passed++))
    else
        ((failed++))
    fi
    echo ""
done

echo "======================================"
echo "Results: ${passed} passed, ${failed} failed"
echo "======================================"

if [[ ${failed} -gt 0 ]]; then
    echo ""
    echo "❌ Some hooks failed. Please check:"
    echo "1. URL format is correct (no spaces, quotes, or extra characters)"
    echo "2. Hook is copied exactly from Render dashboard"
    echo "3. Service is not paused or deleted in Render"
    exit 1
fi

echo ""
echo "✅ All hooks are working!"
