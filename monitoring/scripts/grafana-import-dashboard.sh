#!/usr/bin/env bash
# Import monitoring/dashboards/serveaso-overview.json into Grafana Cloud.
#
# Usage:
#   GRAFANA_URL=https://yourstack.grafana.net \
#   GRAFANA_API_TOKEN=glc_... \
#   ./monitoring/scripts/grafana-import-dashboard.sh
#
# Optional:
#   GRAFANA_FOLDER_UID=serveaso-dev   # create folder first in UI if needed
#   GRAFANA_OVERWRITE=true              # default true
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DASHBOARD_JSON="${ROOT}/monitoring/dashboards/serveaso-overview.json"

GRAFANA_URL="${GRAFANA_URL:?Set GRAFANA_URL (e.g. https://yourstack.grafana.net)}"
GRAFANA_API_TOKEN="${GRAFANA_API_TOKEN:?Set GRAFANA_API_TOKEN (service account or Cloud API key)}"
GRAFANA_FOLDER_UID="${GRAFANA_FOLDER_UID:-}"
GRAFANA_OVERWRITE="${GRAFANA_OVERWRITE:-true}"

GRAFANA_URL="${GRAFANA_URL%/}"

if [[ ! -f "${DASHBOARD_JSON}" ]]; then
  echo "Dashboard file not found: ${DASHBOARD_JSON}" >&2
  exit 1
fi

payload="$(jq -n \
  --argjson dashboard "$(jq 'del(.id)' "${DASHBOARD_JSON}")" \
  --arg folderUid "${GRAFANA_FOLDER_UID}" \
  --argjson overwrite "${GRAFANA_OVERWRITE}" \
  '{
    dashboard: $dashboard,
    overwrite: $overwrite
  }
  + (if $folderUid == "" then {} else {folderUid: $folderUid} end)'
)"

http_code="$(curl -sS -o /tmp/grafana-import-response.json -w "%{http_code}" \
  -X POST "${GRAFANA_URL}/api/dashboards/db" \
  -H "Authorization: Bearer ${GRAFANA_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${payload}")"

if [[ "${http_code}" == "200" ]]; then
  uid="$(jq -r '.uid' /tmp/grafana-import-response.json)"
  url="$(jq -r '.url' /tmp/grafana-import-response.json)"
  echo "Dashboard imported."
  echo "  UID:  ${uid}"
  echo "  URL:  ${GRAFANA_URL}${url}"
  echo ""
  echo "Set GitHub repo variable GRAFANA_DASHBOARD_URL to:"
  echo "  ${GRAFANA_URL}${url}"
else
  echo "Grafana API returned HTTP ${http_code}:" >&2
  cat /tmp/grafana-import-response.json >&2
  exit 1
fi
