#!/usr/bin/env bash
# Phase 2 — verify DEV metrics endpoints and print Grafana Explore queries.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMEOUT="${PHASE2_PROBE_TIMEOUT:-20}"

declare -a NAMES=(
  payments providers utils coupons preferences reviews tickets chat image-uploader
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
)

ok=0
fail=0

echo "=== Phase 2 verify: DEV /metrics on Render ==="
echo ""

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  host="${HOSTS[$i]}"
  url="https://${host}/metrics"
  code="000"
  env_label=""

  if out="$(curl -sS -m "${TIMEOUT}" -w "\n%{http_code}" "${url}" 2>/dev/null || true)"; then
    code="$(printf '%s' "${out}" | tail -n1)"
    body="$(printf '%s' "${out}" | sed '$d' | head -c 400)"
    env_label="$(printf '%s' "${body}" | grep -Eo 'environment="[^"]+"' | head -1 | cut -d'"' -f2 || true)"
  fi

  if [[ "${code}" == "200" ]] && [[ "${body}" == *"http_requests_total"* || "${body}" == *"# HELP"* ]]; then
    printf "  OK   %-18s %s  (metrics environment=%s)\n" "${name}" "${code}" "${env_label:-unknown}"
    ok=$((ok + 1))
  else
    printf "  FAIL %-18s %s\n" "${name}" "${code}"
    fail=$((fail + 1))
  fi
done

total="${#NAMES[@]}"
echo ""
echo "Endpoints: ${ok}/${total} OK"

if [[ -x "${ROOT}/.github/scripts/observability-smoke.sh" ]]; then
  echo ""
  echo "=== CI observability smoke (same probes as deploy email) ==="
  set +e
  "${ROOT}/.github/scripts/observability-smoke.sh" /tmp/phase2-observability.json
  smoke_rc=$?
  set -e
  jq '{status, up, down, total, down_services}' /tmp/phase2-observability.json
  echo "smoke exit: ${smoke_rc}"
fi

echo ""
echo "=== Grafana Explore (Prometheus) — paste after collector is running ==="
echo ""
echo "Scrape health (expect 9 series at 1):"
echo '  up{job="serveaso-render-dev"}'
echo ""
echo "Request rate (Render DEV uses NODE_ENV=production on app metrics):"
echo '  sum by (service) (rate(http_requests_total{environment="production"}[5m]))'
echo ""
echo "5xx rate:"
echo '  sum by (service) (rate(http_requests_total{environment="production",status_code=~"5.."}[5m]))'
echo ""
echo "Import dashboard:"
echo "  GRAFANA_URL=https://YOUR_STACK.grafana.net \\"
echo "  GRAFANA_API_TOKEN=glc_... \\"
echo "  ./monitoring/scripts/grafana-import-dashboard.sh"
echo ""

if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
