#!/usr/bin/env bash
# Trigger a Render deploy hook (dev environment).
# Writes deploy id to /tmp/render-deploy-id.txt when the API returns one.
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

DEPLOY_ID="$(jq -r '.deploy.id // empty' /tmp/render-deploy-response.txt 2>/dev/null || true)"
if [[ -n "${DEPLOY_ID}" && "${DEPLOY_ID}" != "null" ]]; then
  echo "${DEPLOY_ID}" > /tmp/render-deploy-id.txt
  echo "Render deploy id: ${DEPLOY_ID}"
else
  rm -f /tmp/render-deploy-id.txt
  echo "::warning::Deploy hook did not return deploy.id — watch step will pick the latest deploy."
fi

echo "Render deploy triggered successfully."
