#!/usr/bin/env bash
# Probe GET /metrics on all DEV backend services. Writes JSON report for deploy email.
set -euo pipefail

REPORT="${1:-observability-report.json}"
TIMEOUT="${OBSERVABILITY_PROBE_TIMEOUT:-20}"
GRAFANA_DASHBOARD_URL="${GRAFANA_DASHBOARD_URL:-}"

declare -a NAMES=(
  payments providers utils coupons preferences reviews tickets chat image-uploader tracking
)
declare -a HOSTS=(
  payments-vyqp.onrender.com
  providers-k8w7.onrender.com
  utils-jo6c.onrender.com
  coupons-o26r.onrender.com
  preferences.onrender.com
  reviews-7aal.onrender.com
  tickets-3gc8.onrender.com
  chat-b3wl.onrender.com
  imageuploader-5njj.onrender.com
  notifications-mjdp.onrender.com
)

up=0
down=0
down_list=()
results_json="[]"

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  host="${HOSTS[$i]}"
  url="https://${host}/metrics"
  code="000"
  body_head=""

  if out="$(curl -sS -m "${TIMEOUT}" -w "\n%{http_code}" "${url}" 2>/dev/null || true)"; then
    if [[ "${out}" == *$'\n'* ]]; then
      code="${out##*$'\n'}"
      body="${out%$'\n'*}"
    else
      code="${out}"
      body=""
    fi
    body_head="${body:0:200}"
  fi

  ok=false
  if [[ "${code}" == "200" ]] && [[ "${body_head}" == *"http_requests_total"* || "${body_head}" == *"# HELP"* ]]; then
    ok=true
    up=$((up + 1))
  else
    down=$((down + 1))
    down_list+=("${name}")
  fi

  ok_json=false
  if [[ "${ok}" == true ]]; then
    ok_json=true
  fi
  results_json="$(jq -n \
    --argjson arr "${results_json}" \
    --arg name "${name}" \
    --arg host "${host}" \
    --arg code "${code}" \
    --argjson ok "${ok_json}" \
    '$arr + [{service: $name, host: $host, http_code: $code, ok: $ok}]')"
done

total="${#NAMES[@]}"
status="success"
if [[ "${down}" -gt 0 ]]; then
  status="failure"
fi

down_csv="$(IFS=,; echo "${down_list[*]:-}")"

jq -n \
  --arg status "${status}" \
  --argjson up "${up}" \
  --argjson down "${down}" \
  --argjson total "${total}" \
  --arg down_services "${down_csv}" \
  --arg grafana_url "${GRAFANA_DASHBOARD_URL}" \
  --argjson results "${results_json}" \
  '{
    status: $status,
    up: $up,
    down: $down,
    total: $total,
    down_services: (if $down_services == "" then [] else ($down_services | split(",")) end),
    grafana_dashboard_url: (if $grafana_url == "" then null else $grafana_url end),
    results: $results
  }' > "${REPORT}"

echo "Observability smoke: ${up}/${total} targets up (${status})"
if [[ ${#down_list[@]} -gt 0 ]]; then
  echo "Down: ${down_list[*]}"
fi

if [[ "${status}" == "failure" ]]; then
  exit 1
fi
