#!/usr/bin/env bash
# Merge deploy-report-*.json artifacts and send HTML email via SendGrid.
# Env: DEPLOY_NOTIFY_EMAILS (comma-separated), SENDGRID_API_KEY,
#      DEPLOY_NOTIFY_FROM (optional), WORKFLOW_STATUS, ENVIRONMENT, BUILD_VERSION,
#      WORKFLOW_URL, MIGRATE_STATUS (optional)
set -euo pipefail

REPORTS_DIR="${1:-./deploy-reports}"
EMAILS="${DEPLOY_NOTIFY_EMAILS:-}"
API_KEY="${SENDGRID_API_KEY:-}"
FROM="${DEPLOY_NOTIFY_FROM:-deploy@serveaso.com}"
WORKFLOW_STATUS="${WORKFLOW_STATUS:-unknown}"
ENVIRONMENT="${ENVIRONMENT:-unknown}"
BUILD_VERSION="${BUILD_VERSION:-unknown}"
WORKFLOW_URL="${WORKFLOW_URL:-}"
MIGRATE_STATUS="${MIGRATE_STATUS:-skipped}"

if [[ -z "${EMAILS}" ]]; then
  echo "::notice::DEPLOY_NOTIFY_EMAILS not set — skipping deployment email."
  exit 0
fi

if [[ -z "${API_KEY}" ]]; then
  echo "::notice::SENDGRID_API_KEY not set — skipping deployment email. See docs/DEPLOYMENT.md"
  exit 0
fi

mapfile -t REPORT_FILES < <(find "${REPORTS_DIR}" -name 'deploy-report.json' -type f 2>/dev/null | sort)
if [[ ${#REPORT_FILES[@]} -eq 0 ]]; then
  echo "::warning::No deploy-report.json files found under ${REPORTS_DIR}"
  exit 0
fi

MERGED="$(mktemp)"
jq -s '.' "${REPORT_FILES[@]}" > "${MERGED}"

SERVICE_COUNT="$(jq 'length' "${MERGED}")"
SUCCESS_COUNT="$(jq '[.[] | select(.jobStatus == "success")] | length' "${MERGED}")"
FAILED_COUNT="$(jq '[.[] | select(.jobStatus != "success")] | length' "${MERGED}")"

if [[ "${WORKFLOW_STATUS}" == "success" && "${FAILED_COUNT}" -eq 0 ]]; then
  OVERALL="SUCCESS"
  SUBJECT="✅ Serveaso deploy ${ENVIRONMENT} — ${BUILD_VERSION} (${SUCCESS_COUNT}/${SERVICE_COUNT} services)"
else
  OVERALL="ATTENTION"
  SUBJECT="⚠️ Serveaso deploy ${ENVIRONMENT} — ${BUILD_VERSION} (${SUCCESS_COUNT} ok, ${FAILED_COUNT} failed)"
fi

TABLE_ROWS="$(jq -r '
  .[] |
  "<tr>" +
  "<td>" + .label + "</td>" +
  "<td><code>" + .service + "</code></td>" +
  "<td>" + .jobStatus + "</td>" +
  "<td>" + (if .renderStatus != "" then .renderStatus else "—" end) + "</td>" +
  "<td><code>" + (if .renderDeployId != "" then .renderDeployId else (if .buildVersion != "" then .buildVersion else "—" end) end) + "</code></td>" +
  "<td><code>" + (if (.submoduleSha // "") != "" then .submoduleSha[0:8] else .commitSha[0:8] end) + "</code></td>" +
  "</tr>"
' "${MERGED}")"

HTML="$(cat <<EOF
<!DOCTYPE html>
<html>
<body style="font-family: system-ui, sans-serif; color: #222;">
  <h2>Serveaso backend deployment — ${ENVIRONMENT}</h2>
  <p><strong>Overall:</strong> ${OVERALL}</p>
  <ul>
    <li><strong>Build version:</strong> <code>${BUILD_VERSION}</code></li>
    <li><strong>Workflow status:</strong> ${WORKFLOW_STATUS}</li>
    <li><strong>DB migrations:</strong> ${MIGRATE_STATUS}</li>
    <li><strong>Services:</strong> ${SUCCESS_COUNT} succeeded, ${FAILED_COUNT} failed (of ${SERVICE_COUNT})</li>
    <li><strong>Workflow run:</strong> <a href="${WORKFLOW_URL}">${WORKFLOW_URL}</a></li>
  </ul>
  <table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse; font-size: 14px;">
    <thead>
      <tr style="background: #f4f4f4;">
        <th>Service</th>
        <th>Key</th>
        <th>CI job</th>
        <th>Render status</th>
        <th>Deploy / build id</th>
        <th>Commit</th>
      </tr>
    </thead>
    <tbody>
      ${TABLE_ROWS}
    </tbody>
  </table>
  <p style="color: #666; font-size: 12px;">Generated at $(date -u +%Y-%m-%dT%H:%M:%SZ) UTC</p>
</body>
</html>
EOF
)"

TO_JSON="$(printf '%s' "${EMAILS}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | jq -R '{email: .}' | jq -s '.')"

PAYLOAD="$(jq -n \
  --arg from "${FROM}" \
  --arg subject "${SUBJECT}" \
  --arg html "${HTML}" \
  --argjson to "${TO_JSON}" \
  '{
    personalizations: [{to: $to}],
    from: {email: $from, name: "Serveaso Deploy"},
    subject: $subject,
    content: [{type: "text/html", value: $html}]
  }')"

HTTP_CODE="$(curl -sS -o /tmp/sendgrid-response.json -w "%{http_code}" \
  -X POST "https://api.sendgrid.com/v3/mail/send" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")"

if [[ "${HTTP_CODE}" == "202" ]]; then
  echo "Deployment notification email sent to: ${EMAILS}"
else
  echo "::warning::SendGrid returned HTTP ${HTTP_CODE}: $(cat /tmp/sendgrid-response.json)"
  exit 0
fi
