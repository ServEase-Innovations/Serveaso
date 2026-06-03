#!/usr/bin/env bash
# Trigger a Render deploy (dev). Prefers Render API + commitId when API key and service id are set.
# Writes deploy id to /tmp/render-deploy-id.txt when the API returns one.
#
# Usage: render-deploy.sh <deployHookUrl> [servicePath]
# Env: RENDER_API_KEY, RENDER_SVC_ID (optional), GITHUB_TOKEN (for submodule sync is separate step)
set -euo pipefail

HOOK_URL="${1:?Render deploy hook URL required}"
SERVICE_PATH="${2:-}"

COMMIT_SHA=""
if [[ -n "${SERVICE_PATH}" && -d "${SERVICE_PATH}/.git" ]]; then
  COMMIT_SHA="$(git -C "${SERVICE_PATH}" rev-parse HEAD)"
  echo "Deploy commit from ${SERVICE_PATH}: ${COMMIT_SHA}"
fi

trigger_via_api() {
  local body http_code deploy_id payload
  body="$(mktemp)"
  if [[ -n "${COMMIT_SHA}" ]]; then
    payload="$(jq -n --arg c "${COMMIT_SHA}" '{commitId: $c}')"
  else
    payload="{}"
  fi
  http_code="$(curl -sS -o "${body}" -w "%{http_code}" -X POST \
    -H "Authorization: Bearer ${RENDER_API_KEY}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    "https://api.render.com/v1/services/${RENDER_SVC_ID}/deploys" \
    -d "${payload}")"
  deploy_id="$(jq -r '.id // .deploy.id // empty' "${body}" 2>/dev/null || true)"
  cat "${body}" >&2
  echo "" >&2
  echo "Render API deploy HTTP ${http_code}" >&2
  rm -f "${body}"
  if [[ "${http_code}" == "201" || "${http_code}" == "202" ]]; then
    echo "${deploy_id}"
    return 0
  fi
  return 1
}

trigger_via_hook() {
  local url="${HOOK_URL}"
  if [[ -n "${COMMIT_SHA}" ]]; then
    if [[ "${url}" == *"?"* ]]; then
      url="${url}&ref=${COMMIT_SHA}"
    else
      url="${url}?ref=${COMMIT_SHA}"
    fi
    echo "Deploy hook with ref=${COMMIT_SHA}"
  fi
  local http_code
  http_code="$(curl -sS -o /tmp/render-deploy-response.txt -w "%{http_code}" -X POST "${url}")"
  cat /tmp/render-deploy-response.txt || true
  echo ""
  echo "Render hook HTTP ${http_code}"
  [[ "${http_code}" -ge 200 && "${http_code}" -lt 300 ]]
}

DEPLOY_ID=""

if [[ -n "${RENDER_API_KEY:-}" && -n "${RENDER_SVC_ID:-}" ]]; then
  echo "Triggering Render deploy via API (service ${RENDER_SVC_ID})…"
  api_id=""
  if api_id="$(trigger_via_api)" && [[ -n "${api_id}" ]]; then
    DEPLOY_ID="${api_id}"
  else
    echo "::warning::Render API deploy failed — falling back to deploy hook."
  fi
fi

if [[ -z "${DEPLOY_ID}" ]]; then
  echo "Triggering Render deploy via hook…"
  if ! trigger_via_hook; then
    echo "Render deploy hook failed."
    exit 1
  fi
  DEPLOY_ID="$(jq -r '.deploy.id // empty' /tmp/render-deploy-response.txt 2>/dev/null || true)"
fi

if [[ -n "${DEPLOY_ID}" && "${DEPLOY_ID}" != "null" ]]; then
  echo "${DEPLOY_ID}" > /tmp/render-deploy-id.txt
  echo "Render deploy id: ${DEPLOY_ID}"
else
  rm -f /tmp/render-deploy-id.txt
  echo "::warning::No deploy id in response — watch step will use latest deploy on service."
fi

echo "Render deploy trigger sent."
