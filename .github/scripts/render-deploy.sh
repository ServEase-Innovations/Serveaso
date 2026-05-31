#!/usr/bin/env bash
# Trigger a Render deploy hook (dev environment).
set -euo pipefail

HOOK_URL="${1:?Render deploy hook URL required}"

if [[ -z "${HOOK_URL}" ]]; then
  echo "Deploy hook URL is empty. Add the matching GitHub secret (RENDER_DEPLOY_HOOK_<SERVICE>)."
  exit 1
fi

echo "Triggering Render deploy..."
HTTP_CODE="$(curl -sS -o /tmp/render-deploy-response.txt -w "%{http_code}" -X POST "${HOOK_URL}")"

cat /tmp/render-deploy-response.txt || true
echo ""
echo "Render response HTTP ${HTTP_CODE}"

if [[ "${HTTP_CODE}" -lt 200 || "${HTTP_CODE}" -ge 300 ]]; then
  echo "Render deploy hook failed."
  exit 1
fi

echo "Render deploy triggered successfully."
