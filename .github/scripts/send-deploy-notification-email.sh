#!/usr/bin/env bash
# Merge deploy-report-*.json artifacts and send HTML email via SendGrid.
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
  echo "::notice::SENDGRID_API_KEY not set — skipping deployment email."
  exit 0
fi

mapfile -t REPORT_FILES < <(find "${REPORTS_DIR}" -name 'deploy-report.json' -type f 2>/dev/null | sort)
if [[ ${#REPORT_FILES[@]} -eq 0 ]]; then
  echo "::warning::No deploy-report.json files found under ${REPORTS_DIR}"
  ls -laR "${REPORTS_DIR}" 2>/dev/null || true
  exit 0
fi

MERGED="$(mktemp)"
VALID_FILES=()
for f in "${REPORT_FILES[@]}"; do
  if jq -e . "${f}" >/dev/null 2>&1; then
    VALID_FILES+=("${f}")
  else
    echo "::warning::Skipping invalid deploy report: ${f}"
    head -c 200 "${f}" 2>/dev/null || true
    echo ""
  fi
done

if [[ ${#VALID_FILES[@]} -eq 0 ]]; then
  echo "::warning::No valid deploy-report.json files to merge."
  exit 0
fi

jq -s '.' "${VALID_FILES[@]}" > "${MERGED}"

PAYLOAD="$(jq -n \
  --arg from "${FROM}" \
  --arg emails "${EMAILS}" \
  --arg environment "${ENVIRONMENT}" \
  --arg buildVersion "${BUILD_VERSION}" \
  --arg workflowStatus "${WORKFLOW_STATUS}" \
  --arg migrateStatus "${MIGRATE_STATUS}" \
  --arg workflowUrl "${WORKFLOW_URL}" \
  --arg generatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --slurpfile reports "${MERGED}" \
  '
  def short_sha:
    if (.submoduleSha // "") != "" then .submoduleSha
    elif (.commitSha // "") != "" then .commitSha
    else "-" end
    | if length > 8 then .[0:8] else . end;

  def deploy_cell:
    if (.renderDeployId // "") != "" then .renderDeployId
    elif (.buildVersion // "") != "" then .buildVersion
    else "-" end;

  ($reports[0]) as $rows |
  ($rows | length) as $total |
  ($rows | map(select(.jobStatus == "success")) | length) as $ok |
  ($total - $ok) as $failed |
  (if $workflowStatus == "success" and $failed == 0 then
    "[OK] Serveaso deploy \($environment) - \($buildVersion) (\($ok)/\($total) services)"
  else
    "[!] Serveaso deploy \($environment) - \($buildVersion) (\($ok) ok, \($failed) failed)"
  end) as $subject |
  (if $workflowStatus == "success" and $failed == 0 then "SUCCESS" else "ATTENTION" end) as $overall |
  ($rows | map(
    "<tr><td>" + (.label // .service // "-") + "</td>"
    + "<td><code>" + (.service // "-") + "</code></td>"
    + "<td>" + (.jobStatus // "-") + "</td>"
    + "<td>" + (if (.renderStatus // "") != "" then .renderStatus else "-" end) + "</td>"
    + "<td><code>" + deploy_cell + "</code></td>"
    + "<td><code>" + short_sha + "</code></td></tr>"
  ) | join("")) as $tableRows |
  ($emails | split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length > 0)) | map({email: .})) as $to |
  {
    personalizations: [{to: $to}],
    from: {email: $from, name: "Serveaso Deploy"},
    subject: $subject,
    content: [{
      type: "text/html",
      value:
        "<!DOCTYPE html><html><body style=\"font-family:system-ui,sans-serif;color:#222\">"
        + "<h2>Serveaso backend deployment - \($environment)</h2>"
        + "<p><strong>Overall:</strong> \($overall)</p>"
        + "<ul>"
        + "<li><strong>Build version:</strong> <code>\($buildVersion)</code></li>"
        + "<li><strong>Workflow status:</strong> \($workflowStatus)</li>"
        + "<li><strong>DB migrations:</strong> \($migrateStatus)</li>"
        + "<li><strong>Services:</strong> \($ok) succeeded, \($failed) failed (of \($total))</li>"
        + "<li><strong>Workflow run:</strong> <a href=\"\($workflowUrl)\">\($workflowUrl)</a></li>"
        + "</ul>"
        + "<table border=\"1\" cellpadding=\"8\" cellspacing=\"0\" style=\"border-collapse:collapse;font-size:14px\">"
        + "<thead><tr style=\"background:#f4f4f4\">"
        + "<th>Service</th><th>Key</th><th>CI job</th><th>Render status</th><th>Deploy / build id</th><th>Commit</th>"
        + "</tr></thead><tbody>" + $tableRows + "</tbody></table>"
        + "<p style=\"color:#666;font-size:12px\">Generated at \($generatedAt) UTC</p>"
        + "</body></html>"
    }]
  }
  ')"

HTTP_CODE="$(curl -sS -o /tmp/sendgrid-response.json -w "%{http_code}" \
  -X POST "https://api.sendgrid.com/v3/mail/send" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")"

if [[ "${HTTP_CODE}" == "202" ]]; then
  echo "Deployment notification email sent to: ${EMAILS}"
else
  echo "::warning::SendGrid returned HTTP ${HTTP_CODE}: $(cat /tmp/sendgrid-response.json)"
fi
