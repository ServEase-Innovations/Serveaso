#!/usr/bin/env bash
# Poll a Render service deploy and print build + app logs (dev CI).
# Usage: render-watch-deploy.sh <serviceId> [deployId]
# Requires: RENDER_API_KEY, service id (arg 1)
# Optional: deploy id (arg 2 or RENDER_DEPLOY_ID), RENDER_OWNER_ID,
#   DEPLOY_CREATED_AFTER (ISO 8601), RENDER_DEPLOY_WAIT_SECONDS (default 2400)
#   RENDER_WATCH_STRICT_TIMEOUT=true — fail job if still pending/queued at timeout (default: false)
set -euo pipefail

SERVICE_ID="${1:?Render service id required}"
PREFERRED_DEPLOY_ID="${2:-${RENDER_DEPLOY_ID:-}}"
API_KEY="${RENDER_API_KEY:?Set RENDER_API_KEY to watch deploys and fetch logs}"
OWNER_ID="${RENDER_OWNER_ID:-}"
MAX_WAIT="${RENDER_DEPLOY_WAIT_SECONDS:-2400}"
POLL_INTERVAL="${RENDER_DEPLOY_POLL_SECONDS:-15}"
STRICT_TIMEOUT="${RENDER_WATCH_STRICT_TIMEOUT:-false}"
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

curl_api_body() {
  local out_file="$1"
  shift
  local http_code
  http_code="$(curl -sS -o "${out_file}" -w "%{http_code}" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Accept: application/json" \
    "$@")"
  echo "${http_code}"
}

resolve_owner_id() {
  if [[ -n "${OWNER_ID}" ]]; then
    return
  fi
  if [[ ! "${SERVICE_ID}" =~ ^srv- ]]; then
    echo "::error::Invalid Render service id '${SERVICE_ID}'. Use srv-… from the deploy hook URL (https://api.render.com/deploy/srv-XXX?key=…) or dashboard — not dep-… deploy id."
    exit 1
  fi
  echo "Resolving Render workspace (ownerId) from service ${SERVICE_ID}..."
  local body http_code
  http_code="$(curl_api_body /tmp/render-service.json "${API}/services/${SERVICE_ID}")"
  body="$(cat /tmp/render-service.json 2>/dev/null || echo "{}")"
  if [[ "${http_code}" == "404" ]]; then
    echo "::error::Render service ${SERVICE_ID} not found (HTTP 404). Fix RENDER_SERVICE_ID_* or RENDER_DEPLOY_HOOK_* — API key must be from the same Render workspace as the service."
    exit 1
  fi
  if [[ "${http_code}" != "200" ]]; then
    echo "::error::Render API GET /services/${SERVICE_ID} returned HTTP ${http_code}. Check RENDER_API_KEY and service id."
    exit 1
  fi
  OWNER_ID="$(echo "${body}" | jq -r '
    .ownerId
    // .service.ownerId
    // .owner.id
    // empty
  ')"
  if [[ -z "${OWNER_ID}" || "${OWNER_ID}" == "null" ]]; then
    echo "::error::Could not resolve ownerId. Set RENDER_OWNER_ID or check RENDER_SERVICE_ID."
    exit 1
  fi
  echo "Using ownerId: ${OWNER_ID}"
}

find_deploy_id() {
  if [[ -n "${PREFERRED_DEPLOY_ID}" ]]; then
    echo "${PREFERRED_DEPLOY_ID}"
    return
  fi

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
    body="$(curl_api "${API}/services/${SERVICE_ID}/deploys?limit=5")"
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
  local body http_code
  http_code="$(curl_api_body /tmp/render-deploy-status.json \
    "${API}/services/${SERVICE_ID}/deploys/${deploy_id}")"
  if [[ "${http_code}" != "200" ]]; then
    echo "pending"
    return
  fi
  jq -r '.status // .deploy.status // "unknown"' /tmp/render-deploy-status.json
}

fail_job() {
  local message="$1"
  echo "::error::${message}"
  exit 1
}

deploy_started_at() {
  local deploy_id="$1"
  local http_code
  http_code="$(curl_api_body /tmp/render-deploy-status.json \
    "${API}/services/${SERVICE_ID}/deploys/${deploy_id}")"
  if [[ "${http_code}" != "200" ]]; then
    echo ""
    return
  fi
  jq -r '.createdAt // .deploy.createdAt // empty' /tmp/render-deploy-status.json
}

iso_to_epoch() {
  local iso="$1"
  if [[ -z "${iso}" ]]; then
    echo ""
    return
  fi
  # Trim sub-second precision for macOS/BSD date fallback
  local trimmed="${iso%%.*}"
  trimmed="${trimmed%Z}Z"
  date -u -d "${trimmed}" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "${trimmed}" +%s 2>/dev/null || echo ""
}

fetch_logs() {
  local log_type="$1"
  local start_iso="$2"
  local out_file="$3"
  local start_epoch
  start_epoch="$(iso_to_epoch "${start_iso}")"

  local -a base_params=(
    -G
    "${API}/logs"
    --data-urlencode "ownerId=${OWNER_ID}"
    --data-urlencode "resource=${SERVICE_ID}"
    --data-urlencode "type=${log_type}"
    --data-urlencode "limit=${LOG_LIMIT}"
    --data-urlencode "direction=backward"
  )

  local tmp_body="${LOG_DIR}/logs-${log_type}-response.json"
  local http_code

  # Try with startTime first (when valid), then without (Render returns 400 for some ranges).
  for use_start in true false; do
    local -a params=("${base_params[@]}")
    if [[ "${use_start}" == "true" && -n "${start_epoch}" && "${start_epoch}" =~ ^[0-9]+$ ]]; then
      params+=(--data-urlencode "startTime=${start_epoch}")
    elif [[ "${use_start}" == "true" ]]; then
      continue
    fi

    http_code="$(curl_api_body "${tmp_body}" "${params[@]}")"
    if [[ "${http_code}" == "200" ]]; then
      jq -r '
        if .logs then .logs[]
        elif .[]? then .[]
        else empty end
        | .message // .text // .msg // .
        | if type == "string" then . else tostring end
      ' "${tmp_body}" 2>/dev/null > "${out_file}" || cp "${tmp_body}" "${out_file}"
      return 0
    fi
    if [[ "${use_start}" == "false" ]]; then
      echo "(failed to fetch ${log_type} logs — HTTP ${http_code})" > "${out_file}"
      if [[ -s "${tmp_body}" ]]; then
        echo "::warning::Render logs API (${log_type}): $(head -c 500 "${tmp_body}")"
      fi
      return 1
    fi
  done
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

is_queued_status() {
  case "$1" in
    pending|queued|created) return 0 ;;
    *) return 1 ;;
  esac
}

is_active_build_status() {
  case "$1" in
    building|update_in_progress|updating) return 0 ;;
    *) return 1 ;;
  esac
}

service_suspended() {
  local body
  body="$(curl_api "${API}/services/${SERVICE_ID}" 2>/dev/null || echo "{}")"
  echo "${body}" | jq -r '.suspended // .service.suspended // "unknown"'
}

log_recent_deploys() {
  local body
  body="$(curl_api "${API}/services/${SERVICE_ID}/deploys?limit=6" 2>/dev/null || echo "[]")"
  echo "Recent deploys on service ${SERVICE_ID}:"
  echo "${body}" | jq -r '
    def items:
      if type == "array" then .
      elif .deploys then .deploys
      else []
      end;
    [items[] | if .deploy then .deploy else . end | select(.id != null)]
    | .[]
    | "- \(.id)  \(.status)  \(.createdAt // "?")"
  ' 2>/dev/null || echo "(could not list deploys)"
}

# Hook deploy stuck pending while Render skipped it and another deploy went live.
check_superseded_by_live() {
  local our_id="$1"
  local body live_id
  body="$(curl_api "${API}/services/${SERVICE_ID}/deploys?limit=10")"
  live_id="$(echo "${body}" | jq -r --arg id "${our_id}" '
    def items:
      if type == "array" then .
      elif .deploys then .deploys
      else []
      end;
    [items[] | if .deploy then .deploy else . end
      | select(.id != $id and .status == "live")]
    | sort_by(.createdAt) | reverse
    | .[0].id // empty
  ')"
  if [[ -n "${live_id}" && "${live_id}" != "null" ]]; then
    echo "${live_id}"
    return 0
  fi
  return 1
}

log_stuck_hint() {
  local deploy_id="$1"
  local elapsed="$2"
  if [[ "${elapsed}" -lt 300 ]] || (( elapsed % 300 != 0 )); then
    return
  fi
  echo "::warning::Deploy ${deploy_id} still '${status}' after ${elapsed}s — often queued behind another deploy or service suspended. Check Render dashboard."
  echo "Service suspended: $(service_suspended)"
  log_recent_deploys
}

resolve_owner_id

if [[ -n "${PREFERRED_DEPLOY_ID}" ]]; then
  echo "Watching deploy from hook: ${PREFERRED_DEPLOY_ID}"
else
  echo "Watching latest deploy on service ${SERVICE_ID} (created after ${CREATED_AFTER:-any})"
fi

echo "Waiting for Render deploy (max ${MAX_WAIT}s)..."
sleep 8

DEPLOY_ID="${PREFERRED_DEPLOY_ID}"
elapsed=0
status="pending"

while [[ "${elapsed}" -lt "${MAX_WAIT}" ]]; do
  if [[ -z "${DEPLOY_ID}" ]]; then
    DEPLOY_ID="$(find_deploy_id)"
  fi
  if [[ -z "${DEPLOY_ID}" ]]; then
    echo "No deploy found yet (${elapsed}s)..."
    sleep "${POLL_INTERVAL}"
    elapsed=$((elapsed + POLL_INTERVAL))
    continue
  fi

  status="$(deploy_status "${DEPLOY_ID}")"
  echo "Deploy ${DEPLOY_ID}: ${status} (${elapsed}s)"
  started="$(deploy_started_at "${DEPLOY_ID}")"
  fetch_logs "build" "${started}" "${BUILD_LOG_FILE}" || true

  if is_terminal_status "${status}"; then
    break
  fi

  log_stuck_hint "${DEPLOY_ID}" "${elapsed}"

  if is_queued_status "${status}" && [[ -n "${PREFERRED_DEPLOY_ID}" ]]; then
    superseded="$(check_superseded_by_live "${DEPLOY_ID}" || true)"
    if [[ -n "${superseded}" ]]; then
      echo "::notice::Hook deploy ${DEPLOY_ID} still '${status}', but ${superseded} is live (Render may have skipped the queued deploy)."
      status="live"
      DEPLOY_ID="${superseded}"
      break
    fi
  fi

  sleep "${POLL_INTERVAL}"
  elapsed=$((elapsed + POLL_INTERVAL))
done

if [[ -z "${DEPLOY_ID}" ]]; then
  fail_job "Timed out waiting for a Render deploy to appear (service ${SERVICE_ID}). Check the Render dashboard."
fi

if ! is_terminal_status "${status}"; then
  log_recent_deploys
  if is_queued_status "${status}"; then
    if [[ "${STRICT_TIMEOUT}" == "true" ]]; then
      fail_job "Deploy ${DEPLOY_ID} still '${status}' after ${MAX_WAIT}s. Set RENDER_WATCH_STRICT_TIMEOUT=false to treat as inconclusive, or fix Render queue/suspension."
    fi
    echo "::warning::Deploy ${DEPLOY_ID} still '${status}' after ${MAX_WAIT}s — deploy hook ran; Render has not finished (queue/skip). Not failing CI (RENDER_WATCH_STRICT_TIMEOUT=false)."
    echo "Check Render → service → Deploys for ${DEPLOY_ID}."
    exit 0
  fi
  if is_active_build_status "${status}" && [[ "${STRICT_TIMEOUT}" != "true" ]]; then
    echo "::warning::Deploy ${DEPLOY_ID} still '${status}' after ${MAX_WAIT}s — build may still be running on Render. Not failing CI."
    exit 0
  fi
  fail_job "Deploy ${DEPLOY_ID} did not finish within ${MAX_WAIT}s (last status: ${status})."
fi

started="$(deploy_started_at "${DEPLOY_ID}")"

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

write_deploy_outcome() {
  local outcome_status="$1"
  local out_file="${RUNNER_TEMP:-/tmp}/render-deploy-outcome.json"
  mkdir -p "$(dirname "${out_file}")"
  jq -n \
    --arg serviceId "${SERVICE_ID}" \
    --arg deployId "${DEPLOY_ID}" \
    --arg status "${outcome_status}" \
    '{serviceId: $serviceId, deployId: $deployId, status: $status}' > "${out_file}"
}

case "${status}" in
  live)
    write_deploy_outcome "${status}"
    echo "Render deploy succeeded (deploy ${DEPLOY_ID})."
    exit 0
    ;;
  build_failed|update_failed)
    write_deploy_outcome "${status}"
    fail_job "Render deploy failed (${status}). Service ${SERVICE_ID}, deploy ${DEPLOY_ID}. Open Render → service → Deploys for full logs."
    ;;
  canceled|deactivated)
    write_deploy_outcome "${status}"
    fail_job "Render deploy ended with status: ${status} (deploy ${DEPLOY_ID})."
    ;;
  *)
    write_deploy_outcome "${status}"
    fail_job "Unexpected Render deploy status: ${status} (deploy ${DEPLOY_ID}). Only 'live' is treated as success."
    ;;
esac
