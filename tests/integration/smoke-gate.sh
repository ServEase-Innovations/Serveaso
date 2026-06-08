#!/usr/bin/env bash
# DEV smoke gate — automated API tests + manual UI checklist reminder.
# Usage: ./tests/integration/smoke-gate.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

echo "=== Serveaso DEV smoke gate (automated) ==="
echo ""

set +e
npm run test:integration 2>&1 | tee /tmp/serveaso-smoke-gate.log
rc=${PIPESTATUS[0]}
set -e

pass="$(grep -E '^# pass ' /tmp/serveaso-smoke-gate.log 2>/dev/null | awk '{s+=$3} END {print s+0}')"
fail="$(grep -E '^# fail ' /tmp/serveaso-smoke-gate.log 2>/dev/null | awk '{s+=$3} END {print s+0}')"
skip="$(grep -E '^# skipped ' /tmp/serveaso-smoke-gate.log 2>/dev/null | awk '{s+=$3} END {print s+0}')"

echo ""
echo "Automated: pass=${pass} fail=${fail} skip=${skip}"

if [[ "${fail}" -gt 0 ]]; then
  echo "::error::Automated smoke failed — fix before manual UI gate."
  exit 1
fi

echo ""
echo "=== Manual UI smoke (Netlify DEV) — you must complete in browser ==="
echo ""
echo "  UI: https://servease-innovation.netlify.app"
echo ""
echo "  [ ] 1. Customer login (Auth0)"
echo "  [ ] 2. Browse providers → quote → create booking"
echo "  [ ] 3. Razorpay TEST payment → success in Razorpay Dashboard → webhook delivered"
echo "  [ ] 4. Provider login → accept booking → Socket.IO / notifications update"
echo "  [ ] 5. Provider start OTP → complete service (or test cancel)"
echo "  [ ] 6. Admin → Settings → platform-status (uses REACT_APP_ADMIN_PUSH_SECRET)"
echo "  [ ] 7. Optional: coupon MAID99-1ST / COOK99-1ST, review, support ticket"
echo ""
echo "Admin API (replace secret):"
echo '  curl -sS -H "X-Admin-Push-Secret: $SECRET" https://utils-jo6c.onrender.com/api/platform-status | jq .'
echo ""
echo "DEV is done when manual steps above are checked."
exit "${rc}"
