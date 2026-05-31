#!/usr/bin/env bash
# Poll a Render service deploy and print build + app logs (dev CI).
# Requires: RENDER_API_KEY, service id (arg 1)
# Optional: RENDER_OWNER_ID, DEPLOY_CREATED_AFTER (ISO 8601), RENDER_DEPLOY_WAIT_SECONDS (default 1200)
set -euo pipefail

SERVICE_ID="${1:?Render service id required}"
API_KEY="${RENDER_API_KEY:?Set RENDER_API_KEY to watch deploys and fetch logs}"
OWNER_ID="${RENDER_OWNER_ID:-}"
MAX_WAIT="${RENDER_DEPLOY_WAIT_SECONDS:-1200}"
POLL_INTERVAL="${RENDER_DEPLOY_POLL_SECONDS:-15}"
LOG_LIMIT="${RENDER_LOG_LIMIT:-100}"
CREATED_AFTER="${DEPLOY_CREATED_AFTER:-}"

API="https://api.render.com/v1"
LOG_DIR="${RUNNER_TEMP:-/tmp}/render-logs"
mkdir -p "${LOG_DIR}"
BUILD_LOG_FILE="${LOG_DIR}/build.log"
APP_LOG_FILE="${LOG_DIR}/app.log"

curl_api() {
  curl -sS -f \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Accept: application/json" \
    "$@"
}

resolve_owner_id() {
  if [[ -n "${OWNER_ID}" ]]; then
    return
  fi
  echo "Resolving Render workspace (ownerId) from service ${SERVICE_ID}..."
  local body
  body="$(curl_api "${API}/services/${SERVICE_ID}")"
  OWNER_ID="$(echo "${body}" | jq -r '.ownerId // .service.ownerId // empty')"
  if [[ -z "${OWNER_ID}" || "${OWNER_ID}" == "null" ]]; then
    echo "::error::Could not resolve ownerId. Set RENDER_OWNER_ID or check RENDER_SERVICE_ID."
    exit 1
  fi
}

find_deploy_id() {
  local url="${API}/services/${SERVICE_ID}/deploys?limit=10"
  if [[ -n "${CREATED_AFTER}" ]]; then
    url="${url}&createdAfter=${CREATED_AFTER}"
  fi
  local body deploy_id
  body="$(curl_api "${url}")"
  deploy_id="$(echo "${body}" | jq -r '
    def items:
      if type == "array" then .
      elif .deploys then .deploys
      else []
      end;
    [items[] | if .deploy then .deploy else . end | select(.id != null)]
    | sort_by(.createdAt) | reverse
    | .[0].id // empty
  ')"
  if [[ -z "${deploy_id}" ]]; then
    body="$(curl_api "${API}/services/${SERVICE_ID}/deploys?limit=3")"
    deploy_id="$(echo "${body}" | jq -r '
      def items:
        if type == "array" then .
        elif .deploys then .deploys
        else []
        end;
      [items[] | if .deploy then .deploy else . end | select(.id != null)]
      | sort_by(.createdAt) | reverse
      | .[0].id // empty
    ')"
  fi
  echo "${deploy_id}"
}

deploy_status() {
  local deploy_id="$1"
  local body
  body="$(curl_api "${API}/services/${SERVICE_ID}/deploys/${deploy_id}")"
  echo "${body}" | jq -r '.status // .deploy.status // "unknown"'
}

deploy_started_at() {
  local deploy_id="$1"
  local body
  body="$(curl_api "${API}/services/${SERVICE_ID}/deploys/${deploy_id}")"
  echo "${body}" | jq -r '.createdAt // .deploy.createdAt // empty'
}

iso_to_epoch() {
  local iso="$1"
  if [[ -z "${iso}" ]]; then
    echo ""
    return
  fi
  date -u -d "${iso}" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "${iso}" +%s 2>/dev/null || echo ""
}

fetch_logs() {
  local log_type="$1"
  local start_iso="$2"
  local out_file="$3"
  local start_epoch
  start_epoch="$(iso_to_epoch "${start_iso}")"

  local -a params=(
    --get
    "${API}/logs"
    --data-urlencode "ownerId=${OWNER_ID}"
    --data-urlencode "resource=${SERVICE_ID}"
    --data-urlencode "type=${log_type}"
    --data-urlencode "limit=${LOG_LIMIT}"
    --data-urlencode "direction=forward"
  )
  if [[ -n "${start_epoch}" ]]; then
    params+=(--data-urlencode "startTime=${start_epoch}")
  fi

  local body
  if ! body="$(curl_api "${params[@]}")"; then
    echo "(failed to fetch ${log_type} logs)" > "${out_file}"
    return 1
  fi

  echo "${body}" | jq -r '
    if .logs then .logs[]
    elif .[]? then .[]
    else empty end
    | .message // .text // .msg // .
    | if type == "string" then . else tostring end
  ' 2>/dev/null > "${out_file}" || echo "${body}" > "${out_file}"
}

append_summary() {
  local title="$1"
  local file="$2"
  if [[ ! -f "${file}" || ! -s "${file}" ]]; then
    return
  fi
  {
    echo ""
    echo "<details>"
    echo "<summary>${title}</summary>"
    echo ""
    echo '```'
    head -c 45000 "${file}"
    if [[ "$(wc -c < "${file}")" -gt 45000 ]]; then
      echo ""
      echo "... (truncated)"
    fi
    echo '```'
    echo "</details>"
  } >> "${GITHUB_STEP_SUMMARY:-/dev/null}" 2>/dev/null || true
}

is_terminal_status() {
  case "$1" in
    live|build_failed|update_failed|canceled|deactivated) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_owner_id

echo "Waiting for Render deploy on service ${SERVICE_ID} (max ${MAX_WAIT}s)..."
sleep 8

DEPLOY_ID=""
elapsed=0
while [[ "${elapsed}" -lt "${MAX_WAIT}" ]]; do
  DEPLOY_ID="$(find_deploy_id)"
  if [[ -n "${DEPLOY_ID}" ]]; then
    status="$(deploy_status "${DEPLOY_ID}")"
    echo "Deploy ${DEPLOY_ID}: ${status}"
    started="$(deploy_started_at "${DEPLOY_ID}")"
    fetch_logs "build" "${started}" "${BUILD_LOG_FILE}" || true
    if is_terminal_status "${status}"; then
      break
    fi
  else
    echo "No deploy found yet (${elapsed}s)..."
  fi
  sleep "${POLL_INTERVAL}"
  elapsed=$((elapsed + POLL_INTERVAL))
done

if [[ -z "${DEPLOY_ID}" ]]; then
  echo "::warning::Timed out waiting for a Render deploy to appear. Check the Render dashboard."
  exit 0
fi

status="$(deploy_status "${DEPLOY_ID}")"
started="$(deploy_started_at "${DEPLOY_ID}")"

while ! is_terminal_status "${status}" && [[ "${elapsed}" -lt "${MAX_WAIT}" ]]; do
  sleep "${POLL_INTERVAL}"
  elapsed=$((elapsed + POLL_INTERVAL))
  status="$(deploy_status "${DEPLOY_ID}")"
  echo "Deploy ${DEPLOY_ID}: ${status} (${elapsed}s)"
  fetch_logs "build" "${started}" "${BUILD_LOG_FILE}" || true
done

fetch_logs "build" "${started}" "${BUILD_LOG_FILE}" || true
fetch_logs "app" "${started}" "${APP_LOG_FILE}" || true

echo ""
echo "======== Render build logs ========"
cat "${BUILD_LOG_FILE}" 2>/dev/null || echo "(no build logs)"
echo ""
echo "======== Render app logs (tail) ========"
tail -n 80 "${APP_LOG_FILE}" 2>/dev/null || echo "(no app logs)"

{
  echo "### Render deploy"
  echo "- Service: \`${SERVICE_ID}\`"
  echo "- Deploy: \`${DEPLOY_ID}\`"
  echo "- Status: **${status}**"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}" 2>/dev/null || true

append_summary "Build logs" "${BUILD_LOG_FILE}"
append_summary "App logs (sample)" "${APP_LOG_FILE}"

case "${status}" in
  live)
    echo "Render deploy succeeded."
    exit 0
    ;;
  build_failed|update_failed)
    echo "::error::Render deploy failed (${status}). See build logs above."
    exit 1
    ;;
  canceled|deactivated)
    echo "::warning::Render deploy ended with status: ${status}"
    exit 1
    ;;
  *)
    echo "::warning::Deploy did not reach a terminal state within ${MAX_WAIT}s (last: ${status})."
    exit 0
    ;;
esac
