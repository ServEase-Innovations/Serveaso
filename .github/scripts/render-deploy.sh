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

  local http_code
  for method in POST GET; do
    http_code="$(curl -sS -o /tmp/render-deploy-response.txt -w "%{http_code}" -X "${method}" "${url}")"
    echo "${method} ${url%%\?*} → HTTP ${http_code}"
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
    echo "::error::Render deploy hook failed. Check RENDER_DEPLOY_HOOK_REVIEWS secret matches Render → reviews → Deploy Hook."
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
