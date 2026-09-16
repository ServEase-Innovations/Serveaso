#!/usr/bin/env bash
# Trigger a Render deploy (dev). Mirrors Manual Deploy: latest commit on connected branch.
#
# Usage: render-deploy.sh <deployHookUrl> [servicePath]
# Env: RENDER_API_KEY, RENDER_SVC_ID, GH_PAT (for remote verify), RENDER_DEPLOY_USE_REF=true to pin commit
set -euo pipefail

HOOK_URL="${1:?Render deploy hook URL required}"
SERVICE_PATH="${2:-}"
USE_REF="${RENDER_DEPLOY_USE_REF:-false}"
GIT_TOKEN="${GH_PAT:-${GITHUB_TOKEN:-}}"

COMMIT_SHA=""
REMOTE_OK=false

# Debug: Show hook info (mask the key)
HOOK_DEBUG=$(echo "${HOOK_URL}" | sed -E 's/(key=)[^&]*/\1***MASKED***/g')
echo "🔍 Debug: Deploy Hook URL: ${HOOK_DEBUG}"
echo "🔍 Debug: Service Path: ${SERVICE_PATH:-<not set>}"
echo "🔍 Debug: Hook URL length: ${#HOOK_URL} characters"

# Check for common issues
if [[ "${HOOK_URL}" =~ [[:space:]]$ ]]; then
  echo "::warning::⚠️  Deploy hook has trailing whitespace - trimming"
  HOOK_URL="${HOOK_URL%"${HOOK_URL##*[![:space:]]}"}"
fi
if [[ "${HOOK_URL}" =~ ^[[:space:]] ]]; then
  echo "::warning::⚠️  Deploy hook has leading whitespace - trimming"
  HOOK_URL="${HOOK_URL#"${HOOK_URL%%[![:space:]]*}"}"
fi

# Validate URL format
if [[ ! "${HOOK_URL}" =~ ^https:// ]]; then
  echo "::error::❌ Deploy hook does not start with 'https://'"
  echo "::error::Got: ${HOOK_URL:0:50}..."
  echo "::error::Expected format: https://api.render.com/deploy/srv-xxxxx?key=yyyyy"
  exit 1
fi

resolve_remote_url() {
  local origin repo_path
  origin="$(git -C "${SERVICE_PATH}" remote get-url origin)"
  if [[ "${origin}" =~ ^https://github.com/(.+)\.git$ ]]; then
    repo_path="${BASH_REMATCH[1]}"
  elif [[ "${origin}" =~ ^git@github.com:(.+)\.git$ ]]; then
    repo_path="${BASH_REMATCH[1]}"
  else
    return 1
  fi
  echo "https://x-access-token:${GIT_TOKEN}@github.com/${repo_path}.git"
}

if [[ -n "${SERVICE_PATH}" && -d "${SERVICE_PATH}/.git" ]]; then
  COMMIT_SHA="$(git -C "${SERVICE_PATH}" rev-parse HEAD)"
  BRANCH="${RENDER_DEPLOY_BRANCH:-main}"
  echo "Submodule commit: ${COMMIT_SHA}"
  if [[ -n "${GIT_TOKEN}" ]]; then
    REMOTE_URL="$(resolve_remote_url)" || true
    if [[ -n "${REMOTE_URL}" ]] && git ls-remote "${REMOTE_URL}" "refs/heads/${BRANCH}" 2>/dev/null | grep -qF "${COMMIT_SHA}"; then
      REMOTE_OK=true
      echo "Commit is on GitHub (${BRANCH})."
    else
      echo "::warning::Commit ${COMMIT_SHA} is not on github.com yet — hook will deploy latest on branch (like Manual Deploy)."
    fi
  fi
fi

trigger_via_hook() {
  local url="${HOOK_URL}"
  # Default: no ref — same as Render dashboard Manual Deploy (latest on branch).
  if [[ "${USE_REF}" == "true" && -n "${COMMIT_SHA}" && "${REMOTE_OK}" == "true" ]]; then
    if [[ "${url}" == *"?"* ]]; then
      url="${url}&ref=${COMMIT_SHA}"
    else
      url="${url}?ref=${COMMIT_SHA}"
    fi
    echo "Deploy hook with ref=${COMMIT_SHA}"
  else
    echo "Deploy hook for latest commit on Render branch (no ref)"
  fi

  echo "🔍 Debug: Attempting to call Render API..."
  echo "🔍 Debug: Host check: $(echo "${url}" | sed -E 's|^https?://([^/?]+).*|\1|')"
  
  local http_code
  for method in POST GET; do
    echo "🔍 Trying ${method} request..."
    
    # More verbose curl with better error output
    set +e
    http_code=$(curl -sS -v -o /tmp/render-deploy-response.txt -w "%{http_code}" -X "${method}" "${url}" 2>&1 | tee /tmp/curl-debug.txt | tail -1)
    curl_exit=$?
    set -e
    
    echo "${method} ${url%%\?*} → HTTP ${http_code} (curl exit code: ${curl_exit})"
    
    # Show curl debug info on failure
    if [[ ${curl_exit} -ne 0 ]]; then
      echo "::error::❌ curl failed with exit code ${curl_exit}"
      echo "🔍 Debug: curl error details:"
      cat /tmp/curl-debug.txt 2>/dev/null | grep -E "(Could not resolve|Connection|timeout|SSL)" || true
    fi
    
    cat /tmp/render-deploy-response.txt || true
    echo ""
    if [[ "${http_code}" -ge 200 && "${http_code}" -lt 300 ]]; then
      return 0
    fi
  done
  return 1
}

trigger_via_api() {
  local body http_code deploy_id payload
  body="$(mktemp)"
  if [[ "${REMOTE_OK}" == "true" && -n "${COMMIT_SHA}" ]]; then
    payload="$(jq -n --arg c "${COMMIT_SHA}" '{commitId: $c}')"
  else
    payload="{}"
    echo "API deploy without commitId (latest on branch)" >&2
  fi
  http_code="$(curl -sS -o "${body}" -w "%{http_code}" -X POST \
    -H "Authorization: Bearer ${RENDER_API_KEY}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    "https://api.render.com/v1/services/${RENDER_SVC_ID}/deploys" \
    -d "${payload}")"
  deploy_id="$(jq -r '.id // .deploy.id // empty' "${body}" 2>/dev/null || true)"
  cat "${body}" >&2
  echo "Render API HTTP ${http_code}" >&2
  rm -f "${body}"
  if [[ "${http_code}" == "201" || "${http_code}" == "202" ]] && [[ -n "${deploy_id}" ]]; then
    echo "${deploy_id}"
    return 0
  fi
  return 1
}

DEPLOY_ID=""

if [[ -n "${RENDER_API_KEY:-}" && -n "${RENDER_SVC_ID:-}" ]]; then
  echo "Triggering via Render API…"
  api_id=""
  if api_id="$(trigger_via_api)" && [[ -n "${api_id}" ]]; then
    DEPLOY_ID="${api_id}"
  else
    echo "::warning::Render API failed — using deploy hook."
  fi
fi

if [[ -z "${DEPLOY_ID}" ]]; then
  echo "Triggering via deploy hook…"
  if ! trigger_via_hook; then
    echo "::error::Render deploy hook failed. Check that the deploy hook URL is correct and matches the Render service."
    echo "::error::Expected URL format: https://api.render.com/deploy/srv-xxxxx?key=xxxxx"
    echo "::error::Verify RENDER_DEPLOY_HOOK_* secret in GitHub Actions matches Render dashboard → Your Service → Deploy Hook"
    exit 1
  fi
  DEPLOY_ID="$(jq -r '.deploy.id // empty' /tmp/render-deploy-response.txt 2>/dev/null || true)"
fi

if [[ -n "${DEPLOY_ID}" && "${DEPLOY_ID}" != "null" ]]; then
  echo "${DEPLOY_ID}" > /tmp/render-deploy-id.txt
  echo "Render deploy id: ${DEPLOY_ID}"
else
  rm -f /tmp/render-deploy-id.txt
fi

echo "Render deploy triggered."
