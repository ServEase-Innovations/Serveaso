#!/usr/bin/env bash
# Merge deploy-report-*.json artifacts and send HTML email via SendGrid.
set -euo pipefail

REPORTS_DIR="${1:-./deploy-reports}"
EMAILS="$(printf '%s' "${DEPLOY_NOTIFY_EMAILS:-}" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
API_KEY="$(printf '%s' "${SENDGRID_API_KEY:-}" | tr -d '\r\n[:space:]')"
FROM="$(printf '%s' "${DEPLOY_NOTIFY_FROM:-deploy@serveaso.com}" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
SENDGRID_API_URL="${SENDGRID_API_URL:-https://api.sendgrid.com/v3/mail/send}"
WORKFLOW_STATUS="${WORKFLOW_STATUS:-unknown}"
ENVIRONMENT="${ENVIRONMENT:-unknown}"
BUILD_VERSION="${BUILD_VERSION:-unknown}"
WORKFLOW_URL="${WORKFLOW_URL:-}"
MIGRATE_STATUS="${MIGRATE_STATUS:-skipped}"
RUN_SMOKE_TESTS="${RUN_SMOKE_TESTS:-false}"
INTEGRATION_JOB_RESULT="${INTEGRATION_JOB_RESULT:-skipped}"
INTEGRATION_STATUS="${INTEGRATION_STATUS:-}"
INTEGRATION_PASS="${INTEGRATION_PASS:-0}"
INTEGRATION_FAIL="${INTEGRATION_FAIL:-0}"
INTEGRATION_SKIP="${INTEGRATION_SKIP:-0}"
OBSERVABILITY_REPORTS_DIR="${OBSERVABILITY_REPORTS_DIR:-./observability-reports}"
OBSERVABILITY_JOB_RESULT="${OBSERVABILITY_JOB_RESULT:-skipped}"
OBSERVABILITY_STATUS="${OBSERVABILITY_STATUS:-}"
OBSERVABILITY_UP="${OBSERVABILITY_UP:-0}"
OBSERVABILITY_TOTAL="${OBSERVABILITY_TOTAL:-0}"
OBSERVABILITY_DOWN="${OBSERVABILITY_DOWN:-0}"
GRAFANA_DASHBOARD_URL="${GRAFANA_DASHBOARD_URL:-}"

if [[ -z "${EMAILS}" ]]; then
  echo "::notice::DEPLOY_NOTIFY_EMAILS not set — skipping deployment email."
  exit 0
fi

if [[ -z "${API_KEY}" ]]; then
  echo "::notice::SENDGRID_API_KEY not set — skipping deployment email."
  exit 0
fi

mapfile -t REPORT_FILES < <(
  find "${REPORTS_DIR}" -type f \( -name 'deploy-report.json' -o -name 'deploy-report-*.json' \) 2>/dev/null | sort
)
if [[ ${#REPORT_FILES[@]} -eq 0 ]]; then
  echo "::warning::No deploy report JSON files found under ${REPORTS_DIR}"
  ls -laR "${REPORTS_DIR}" 2>/dev/null || true
  exit 0
fi

echo "Found ${#REPORT_FILES[@]} deploy report file(s): ${REPORT_FILES[*]}"

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

# Each artifact file is one service object; produce a single JSON array for the email template.
jq -s '[.[] | if type == "array" then .[] else . end | select(type == "object")]' "${VALID_FILES[@]}" > "${MERGED}"
SERVICE_COUNT="$(jq 'length' "${MERGED}")"
echo "Merged ${SERVICE_COUNT} service report(s) for email."

OBS_REPORT_FILE=""
mapfile -t OBS_CANDIDATES < <(
  find "${OBSERVABILITY_REPORTS_DIR}" -name 'observability-report.json' -type f 2>/dev/null | sort
)
if [[ ${#OBS_CANDIDATES[@]} -gt 0 ]]; then
  OBS_REPORT_FILE="${OBS_CANDIDATES[0]}"
elif [[ -f "observability-report.json" ]]; then
  OBS_REPORT_FILE="observability-report.json"
fi

OBS_JQ_ARGS=()
if [[ -n "${OBS_REPORT_FILE}" ]] && jq -e . "${OBS_REPORT_FILE}" >/dev/null 2>&1; then
  OBS_JQ_ARGS+=(--slurpfile obsReport "${OBS_REPORT_FILE}")
  echo "Loaded observability report: ${OBS_REPORT_FILE}"
else
  OBS_JQ_ARGS+=(--argjson obsReport '[{}]')
fi

PAYLOAD="$(jq -n \
  --arg from "${FROM}" \
  --arg emails "${EMAILS}" \
  --arg environment "${ENVIRONMENT}" \
  --arg buildVersion "${BUILD_VERSION}" \
  --arg workflowStatus "${WORKFLOW_STATUS}" \
  --arg migrateStatus "${MIGRATE_STATUS}" \
  --arg workflowUrl "${WORKFLOW_URL}" \
  --arg generatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg runSmokeTests "${RUN_SMOKE_TESTS}" \
  --arg integrationJobResult "${INTEGRATION_JOB_RESULT}" \
  --arg integrationStatus "${INTEGRATION_STATUS}" \
  --arg integrationPass "${INTEGRATION_PASS}" \
  --arg integrationFail "${INTEGRATION_FAIL}" \
  --arg integrationSkip "${INTEGRATION_SKIP}" \
  --arg observabilityJobResult "${OBSERVABILITY_JOB_RESULT}" \
  --arg observabilityStatus "${OBSERVABILITY_STATUS}" \
  --arg observabilityUp "${OBSERVABILITY_UP}" \
  --arg observabilityTotal "${OBSERVABILITY_TOTAL}" \
  --arg observabilityDown "${OBSERVABILITY_DOWN}" \
  --arg grafanaDashboardUrl "${GRAFANA_DASHBOARD_URL}" \
  "${OBS_JQ_ARGS[@]}" \
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

  def badge($text; $bg; $fg):
    "<span style=\"display:inline-block;padding:4px 10px;border-radius:999px;font-size:12px;font-weight:600;"
    + "background:\($bg);color:\($fg);text-transform:uppercase;letter-spacing:0.03em;\">\($text)</span>";

  def job_badge:
    (.jobStatus // "unknown") as $s |
    if $s == "success" then badge($s; "#d1fae5"; "#065f46")
    elif ($s == "failure" or $s == "failed") then badge($s; "#fee2e2"; "#991b1b")
    elif $s == "skipped" then badge($s; "#e5e7eb"; "#374151")
    else badge($s; "#fef3c7"; "#92400e") end;

  def render_badge:
    (if (.renderStatus // "") != "" then .renderStatus else "-" end) as $r |
    if $r == "live" then badge($r; "#d1fae5"; "#065f46")
    elif ($r == "build_failed" or $r == "update_failed" or $r == "canceled") then badge($r; "#fee2e2"; "#991b1b")
    elif $r == "-" then badge($r; "#f3f4f6"; "#6b7280")
    else badge($r; "#dbeafe"; "#1e40af") end;

  def meta_badge($value):
    if $value == "success" then badge($value; "#d1fae5"; "#065f46")
    elif ($value == "failure" or $value == "failed") then badge($value; "#fee2e2"; "#991b1b")
    elif $value == "skipped" then badge($value; "#e5e7eb"; "#374151")
    else badge($value; "#e0e7ff"; "#3730a3") end;

  def service_bar:
    (.jobStatus // "") as $s |
    (if $s == "success" then "#10b981" else "#ef4444" end) as $color |
    "<tr><td style=\"padding:8px 0;font-size:13px;color:#334155;width:140px;\">" + (.label // .service // "-")
    + "</td><td style=\"padding:8px 0;\">"
    + "<div style=\"background:#e2e8f0;border-radius:8px;height:14px;overflow:hidden;\">"
    + "<div style=\"background:\($color);width:100%;height:14px;border-radius:8px;\"></div>"
    + "</div></td><td style=\"padding:8px 0 8px 12px;width:90px;text-align:right;\">" + job_badge + "</td></tr>";

  def donut_chart($ok; $total):
    if $total == 0 then
      "<svg width=\"140\" height=\"140\" viewBox=\"0 0 140 140\" xmlns=\"http://www.w3.org/2000/svg\">"
      + "<circle cx=\"70\" cy=\"70\" r=\"54\" fill=\"none\" stroke=\"#e5e7eb\" stroke-width=\"14\"/>"
      + "<text x=\"70\" y=\"76\" text-anchor=\"middle\" font-size=\"22\" font-weight=\"700\" fill=\"#6b7280\">0%</text>"
      + "</svg>"
    else
      (($ok / $total) * 100 | floor) as $pct |
      (2 * 3.14159265 * 54) as $circ |
      ($circ * (1 - ($ok / $total))) as $offset |
      (if $ok == $total then "#10b981" elif $ok == 0 then "#ef4444" else "#6366f1" end) as $stroke |
      "<svg width=\"140\" height=\"140\" viewBox=\"0 0 140 140\" xmlns=\"http://www.w3.org/2000/svg\">"
      + "<circle cx=\"70\" cy=\"70\" r=\"54\" fill=\"none\" stroke=\"#e5e7eb\" stroke-width=\"14\"/>"
      + "<circle cx=\"70\" cy=\"70\" r=\"54\" fill=\"none\" stroke=\"\($stroke)\" stroke-width=\"14\""
      + " stroke-linecap=\"round\" stroke-dasharray=\"\($circ)\" stroke-dashoffset=\"\($offset)\""
      + " transform=\"rotate(-90 70 70)\"/>"
      + "<text x=\"70\" y=\"68\" text-anchor=\"middle\" font-size=\"26\" font-weight=\"700\" fill=\"#111827\">\($pct)%</text>"
      + "<text x=\"70\" y=\"88\" text-anchor=\"middle\" font-size=\"11\" fill=\"#6b7280\">success</text>"
      + "</svg>"
    end;

  ($reports[0]) as $raw |
  (if ($raw | type) == "array" then $raw else [$raw] end) as $rows |
  ($rows | length) as $total |
  ($rows | map(select(.jobStatus == "success")) | length) as $ok |
  ($total - $ok) as $failed |
  (if $total > 0 then (($ok / $total) * 100 | floor) else 0 end) as $pct |
  (if ($environment | ascii_downcase) == "dev" and $runSmokeTests == "true" and $integrationJobResult != "skipped" then true else false end) as $integrationRan |
  (if $integrationRan then
    if (($integrationFail | if . == "" then 0 else tonumber end) > 0) or $integrationStatus == "failure" or $integrationJobResult == "failure" then "failure"
    elif $integrationJobResult == "success" or $integrationStatus == "success" then "success"
    else $integrationJobResult end
  else "skipped" end) as $integrationOutcome |
  (if $integrationRan and $integrationOutcome == "success" then
    "Integration: \($integrationPass) passed, \($integrationSkip) skipped"
  elif $integrationRan and $integrationOutcome == "failure" then
    "Integration: \($integrationFail) failed (\($integrationPass) passed)"
  elif ($environment | ascii_downcase) != "dev" then "Integration: not run (prod deploy)"
  elif $runSmokeTests != "true" then "Integration: disabled for this run"
  else "Integration: skipped" end) as $integrationSummary |
  (if ($environment | ascii_downcase) == "dev" and $runSmokeTests == "true" and $observabilityJobResult != "skipped" then true else false end) as $observabilityRan |
  (($obsReport[0] // {}) | if type == "object" then . else {} end) as $obsData |
  (if ($obsData | has("up")) then ($obsData.up | tostring) elif $observabilityUp != "" then $observabilityUp else "0" end) as $obsUpStr |
  (if ($obsData | has("total")) then ($obsData.total | tostring) elif $observabilityTotal != "" then $observabilityTotal else "0" end) as $obsTotalStr |
  (if ($obsData | has("down")) then ($obsData.down | tostring) elif $observabilityDown != "" then $observabilityDown else "0" end) as $obsDownStr |
  ($obsUpStr | if . == "" then 0 else tonumber end) as $obsUp |
  ($obsTotalStr | if . == "" then 0 else tonumber end) as $obsTotal |
  ($obsDownStr | if . == "" then 0 else tonumber end) as $obsDown |
  (if $observabilityRan then
    if (($obsDown > 0) or $observabilityStatus == "failure" or $observabilityJobResult == "failure") then "failure"
    elif $observabilityJobResult == "success" or $observabilityStatus == "success" then "success"
    else $observabilityJobResult end
  else "skipped" end) as $observabilityOutcome |
  (if $observabilityRan and $observabilityOutcome == "success" then
    "Metrics: \($obsUp)/\($obsTotal) targets up"
  elif $observabilityRan and $observabilityOutcome == "failure" then
    "Metrics: \($obsDown) down (\($obsUp)/\($obsTotal) up)"
  elif ($environment | ascii_downcase) != "dev" then "Metrics: not run (prod deploy)"
  elif $runSmokeTests != "true" then "Metrics: disabled for this run"
  else "Metrics: skipped" end) as $observabilitySummary |
  (($obsData.down_services // []) | if type == "array" then join(", ") else "" end) as $obsDownServices |
  (if ($obsData.grafana_dashboard_url // "") != "" then $obsData.grafana_dashboard_url elif $grafanaDashboardUrl != "" then $grafanaDashboardUrl else "" end) as $grafanaUrl |
  (if $workflowStatus == "success" and $failed == 0 and ($integrationOutcome == "success" or $integrationOutcome == "skipped") and ($observabilityOutcome == "success" or $observabilityOutcome == "skipped") then
    "[OK] Serveaso deploy \($environment) - \($buildVersion) (\($ok)/\($total) services)"
  elif $integrationOutcome == "failure" then
    "[!] Serveaso deploy \($environment) - \($buildVersion) — integration tests failed"
  elif $observabilityOutcome == "failure" then
    "[!] Serveaso deploy \($environment) - \($buildVersion) — metrics targets down"
  else
    "[!] Serveaso deploy \($environment) - \($buildVersion) (\($ok) ok, \($failed) failed)"
  end) as $subject |
  (if $workflowStatus == "success" and $failed == 0 and ($integrationOutcome == "success" or $integrationOutcome == "skipped") and ($observabilityOutcome == "success" or $observabilityOutcome == "skipped") then "All systems deployed"
   elif $integrationOutcome == "failure" then "Deploy OK — integration smoke failed"
   elif $observabilityOutcome == "failure" then "Deploy OK — observability smoke failed"
   else "Review required" end) as $headline |
  (if $workflowStatus == "success" and $failed == 0 and ($integrationOutcome == "success" or $integrationOutcome == "skipped") and ($observabilityOutcome == "success" or $observabilityOutcome == "skipped") then "#10b981"
   elif ($integrationOutcome == "failure" or $observabilityOutcome == "failure") then "#ef4444"
   else "#f59e0b" end) as $accent |
  (if $workflowStatus == "success" and $failed == 0 and ($integrationOutcome == "success" or $integrationOutcome == "skipped") and ($observabilityOutcome == "success" or $observabilityOutcome == "skipped") then "#ecfdf5"
   elif ($integrationOutcome == "failure" or $observabilityOutcome == "failure") then "#fef2f2"
   else "#fffbeb" end) as $accentBg |
  ($rows | map(service_bar) | join("")) as $barRows |
  ($rows | map(
    "<tr>"
    + "<td style=\"padding:12px 14px;border-bottom:1px solid #e2e8f0;font-weight:600;color:#1e293b;\">" + (.label // .service // "-") + "</td>"
    + "<td style=\"padding:12px 14px;border-bottom:1px solid #e2e8f0;\"><code style=\"background:#f1f5f9;padding:2px 6px;border-radius:4px;font-size:12px;\">" + (.service // "-") + "</code></td>"
    + "<td style=\"padding:12px 14px;border-bottom:1px solid #e2e8f0;\">" + job_badge + "</td>"
    + "<td style=\"padding:12px 14px;border-bottom:1px solid #e2e8f0;\">" + render_badge + "</td>"
    + "<td style=\"padding:12px 14px;border-bottom:1px solid #e2e8f0;font-size:12px;color:#475569;\"><code>" + deploy_cell + "</code></td>"
    + "<td style=\"padding:12px 14px;border-bottom:1px solid #e2e8f0;font-size:12px;color:#475569;\"><code>" + short_sha + "</code></td>"
    + "</tr>"
  ) | join("")) as $tableRows |
  (if $total > 0 and $ok > 0 then (($ok / $total) * 100 | floor) else 0 end) as $okWidth |
  (if $total > 0 and $failed > 0 then (($failed / $total) * 100 | floor) else 0 end) as $failWidth |
  ($emails | split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length > 0)) | map({email: .})) as $to |
  {
    personalizations: [{to: $to}],
    from: {email: $from, name: "Serveaso Deploy"},
    subject: $subject,
    content: [{
      type: "text/html",
      value: (
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"></head>"
        + "<body style=\"margin:0;padding:0;background:#f1f5f9;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#1e293b;\">"
        + "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:#f1f5f9;padding:24px 12px;\"><tr><td align=\"center\">"
        + "<table role=\"presentation\" width=\"640\" cellpadding=\"0\" cellspacing=\"0\" style=\"max-width:640px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 10px 30px rgba(15,23,42,0.08);\">"

        + "<tr><td style=\"background:linear-gradient(135deg,#4f46e5 0%,#7c3aed 55%,#0ea5e9 100%);padding:28px 32px;color:#ffffff;\">"
        + "<div style=\"font-size:12px;letter-spacing:0.12em;text-transform:uppercase;opacity:0.9;\">Serveaso Deploy Report</div>"
        + "<div style=\"font-size:28px;font-weight:700;margin-top:8px;\">\($environment | ascii_upcase) deployment</div>"
        + "<div style=\"font-size:15px;margin-top:6px;opacity:0.95;\">\($headline)</div>"
        + "</td></tr>"

        + "<tr><td style=\"padding:24px 32px 8px;\">"
        + "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\"><tr>"
        + "<td width=\"33%\" style=\"padding:8px;\"><div style=\"background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;padding:16px;text-align:center;\">"
        + "<div style=\"font-size:28px;font-weight:700;color:#4f46e5;\">\($total)</div><div style=\"font-size:12px;color:#64748b;margin-top:4px;\">Services</div></div></td>"
        + "<td width=\"33%\" style=\"padding:8px;\"><div style=\"background:#ecfdf5;border:1px solid #a7f3d0;border-radius:12px;padding:16px;text-align:center;\">"
        + "<div style=\"font-size:28px;font-weight:700;color:#059669;\">\($ok)</div><div style=\"font-size:12px;color:#047857;margin-top:4px;\">Succeeded</div></div></td>"
        + "<td width=\"33%\" style=\"padding:8px;\"><div style=\"background:#fef2f2;border:1px solid #fecaca;border-radius:12px;padding:16px;text-align:center;\">"
        + "<div style=\"font-size:28px;font-weight:700;color:#dc2626;\">\($failed)</div><div style=\"font-size:12px;color:#b91c1c;margin-top:4px;\">Failed</div></div></td>"
        + "</tr></table></td></tr>"

        + "<tr><td style=\"padding:8px 32px 24px;\">"
        + "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:\($accentBg);border:1px solid \($accent);border-radius:12px;\"><tr>"
        + "<td style=\"padding:20px;width:160px;vertical-align:middle;text-align:center;\">" + donut_chart($ok; $total) + "</td>"
        + "<td style=\"padding:20px 20px 20px 0;vertical-align:middle;\">"
        + "<div style=\"font-size:14px;font-weight:600;color:#334155;margin-bottom:10px;\">Deploy health overview</div>"
        + "<div style=\"background:#e2e8f0;border-radius:999px;height:18px;overflow:hidden;\">"
        + (if $okWidth > 0 then "<div style=\"display:inline-block;background:#10b981;height:18px;width:\($okWidth)%;\"></div>" else "" end)
        + (if $failWidth > 0 then "<div style=\"display:inline-block;background:#ef4444;height:18px;width:\($failWidth)%;\"></div>" else "" end)
        + "</div>"
        + "<div style=\"font-size:12px;color:#64748b;margin-top:8px;\">\($ok) of \($total) services healthy (\($pct)%)</div>"
        + "<table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\" style=\"margin-top:14px;font-size:13px;\"><tr>"
        + "<td style=\"padding-right:16px;\"><strong>Build</strong><br><code style=\"font-size:11px;\">\($buildVersion)</code></td>"
        + "<td style=\"padding-right:16px;\"><strong>Workflow</strong><br>" + meta_badge($workflowStatus) + "</td>"
        + "<td style=\"padding-right:16px;\"><strong>Migrations</strong><br>" + meta_badge($migrateStatus) + "</td>"
        + "<td style=\"padding-right:16px;\"><strong>Integration</strong><br>" + meta_badge($integrationOutcome) + "</td>"
        + "<td><strong>Metrics</strong><br>" + meta_badge($observabilityOutcome) + "</td>"
        + "</tr></table>"
        + "</td></tr></table></td></tr>"

        + (if $integrationRan then
          "<tr><td style=\"padding:0 32px 24px;\">"
          + "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;\"><tr><td style=\"padding:18px 20px;\">"
          + "<div style=\"font-size:15px;font-weight:700;color:#1e293b;margin-bottom:8px;\">Integration tests (DEV smoke)</div>"
          + "<div style=\"font-size:13px;color:#475569;margin-bottom:12px;\">\($integrationSummary)</div>"
          + "<table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\" style=\"font-size:13px;\"><tr>"
          + "<td style=\"padding-right:20px;\"><strong>Passed</strong><br><span style=\"font-size:20px;font-weight:700;color:#059669;\">\($integrationPass)</span></td>"
          + "<td style=\"padding-right:20px;\"><strong>Failed</strong><br><span style=\"font-size:20px;font-weight:700;color:#dc2626;\">\($integrationFail)</span></td>"
          + "<td><strong>Skipped</strong><br><span style=\"font-size:20px;font-weight:700;color:#6b7280;\">\($integrationSkip)</span></td>"
          + "</tr></table></td></tr></table></td></tr>"
        else
          "<tr><td style=\"padding:0 32px 24px;\">"
          + "<div style=\"font-size:13px;color:#64748b;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;padding:14px 18px;\">"
          + "<strong>Integration tests:</strong> \($integrationSummary)"
          + "</div></td></tr>"
        end)

        + (if $observabilityRan then
          "<tr><td style=\"padding:0 32px 24px;\">"
          + "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;\"><tr><td style=\"padding:18px 20px;\">"
          + "<div style=\"font-size:15px;font-weight:700;color:#1e293b;margin-bottom:8px;\">Observability (Prometheus /metrics)</div>"
          + "<div style=\"font-size:13px;color:#475569;margin-bottom:12px;\">\($observabilitySummary)"
          + (if $obsDownServices != "" then " — down: <code>\($obsDownServices)</code>" else "" end)
          + "</div>"
          + "<table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\" style=\"font-size:13px;\"><tr>"
          + "<td style=\"padding-right:20px;\"><strong>Up</strong><br><span style=\"font-size:20px;font-weight:700;color:#059669;\">\($obsUp)</span></td>"
          + "<td style=\"padding-right:20px;\"><strong>Down</strong><br><span style=\"font-size:20px;font-weight:700;color:#dc2626;\">\($obsDown)</span></td>"
          + "<td><strong>Total</strong><br><span style=\"font-size:20px;font-weight:700;color:#4f46e5;\">\($obsTotal)</span></td>"
          + "</tr></table>"
          + (if $grafanaUrl != "" then
            "<div style=\"margin-top:14px;\"><a href=\"\($grafanaUrl)\" style=\"color:#4f46e5;font-weight:600;text-decoration:none;\">Open Grafana dashboard →</a></div>"
          else "" end)
          + "</td></tr></table></td></tr>"
        else
          "<tr><td style=\"padding:0 32px 24px;\">"
          + "<div style=\"font-size:13px;color:#64748b;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;padding:14px 18px;\">"
          + "<strong>Observability:</strong> \($observabilitySummary)"
          + "</div></td></tr>"
        end)

        + "<tr><td style=\"padding:0 32px 8px;\"><div style=\"font-size:16px;font-weight:700;color:#1e293b;\">Service status chart</div></td></tr>"
        + "<tr><td style=\"padding:0 32px 24px;\"><table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\">" + $barRows + "</table></td></tr>"

        + "<tr><td style=\"padding:0 32px 8px;\"><div style=\"font-size:16px;font-weight:700;color:#1e293b;\">Deployment details</div></td></tr>"
        + "<tr><td style=\"padding:0 32px 24px;\">"
        + "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"border:1px solid #e2e8f0;border-radius:12px;overflow:hidden;font-size:13px;\">"
        + "<thead><tr style=\"background:#f8fafc;\">"
        + "<th align=\"left\" style=\"padding:12px 14px;color:#64748b;font-size:11px;text-transform:uppercase;letter-spacing:0.06em;\">Service</th>"
        + "<th align=\"left\" style=\"padding:12px 14px;color:#64748b;font-size:11px;text-transform:uppercase;letter-spacing:0.06em;\">Key</th>"
        + "<th align=\"left\" style=\"padding:12px 14px;color:#64748b;font-size:11px;text-transform:uppercase;letter-spacing:0.06em;\">CI job</th>"
        + "<th align=\"left\" style=\"padding:12px 14px;color:#64748b;font-size:11px;text-transform:uppercase;letter-spacing:0.06em;\">Render</th>"
        + "<th align=\"left\" style=\"padding:12px 14px;color:#64748b;font-size:11px;text-transform:uppercase;letter-spacing:0.06em;\">Deploy id</th>"
        + "<th align=\"left\" style=\"padding:12px 14px;color:#64748b;font-size:11px;text-transform:uppercase;letter-spacing:0.06em;\">Commit</th>"
        + "</tr></thead><tbody>" + $tableRows + "</tbody></table></td></tr>"

        + "<tr><td style=\"padding:0 32px 28px;text-align:center;\">"
        + "<a href=\"\($workflowUrl)\" style=\"display:inline-block;background:#4f46e5;color:#ffffff;text-decoration:none;font-weight:600;"
        + "padding:12px 24px;border-radius:10px;font-size:14px;\">View GitHub Actions run</a>"
        + "<div style=\"font-size:12px;color:#94a3b8;margin-top:16px;\">Generated at \($generatedAt) UTC · Serveaso CI/CD</div>"
        + "</td></tr>"

        + "</table></td></tr></table></body></html>"
      )
    }]
  }
  ')"

RECIPIENT_COUNT="$(printf '%s' "${PAYLOAD}" | jq '.personalizations[0].to | length')"
if [[ "${RECIPIENT_COUNT}" -eq 0 ]]; then
  echo "::warning::No valid recipient emails after parsing DEPLOY_NOTIFY_EMAILS."
  exit 0
fi

echo "SendGrid: POST ${SENDGRID_API_URL} | from=${FROM} | recipients=${RECIPIENT_COUNT}"

HTTP_CODE="$(curl -sS -D /tmp/sendgrid-response-headers.txt -o /tmp/sendgrid-response.json -w "%{http_code}" \
  -X POST "${SENDGRID_API_URL}" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")"

MESSAGE_ID="$(grep -i '^x-message-id:' /tmp/sendgrid-response-headers.txt 2>/dev/null | sed 's/^[Xx]-[Mm]essage-[Ii]d:[[:space:]]*//' | tr -d '\r')"

if [[ "${HTTP_CODE}" == "202" ]]; then
  echo "Deployment notification email accepted by SendGrid (HTTP 202)."
  echo "Recipients: ${EMAILS}"
  if [[ -n "${MESSAGE_ID}" ]]; then
    echo "SendGrid message id: ${MESSAGE_ID}"
    echo "Search Activity for this id or recipient in the same SendGrid account that owns the API key."
  else
    echo "::notice::SendGrid returned 202 but no X-Message-Id header — confirm you are viewing the correct SendGrid account/subuser."
  fi
else
  echo "::warning::SendGrid returned HTTP ${HTTP_CODE}: $(cat /tmp/sendgrid-response.json)"
fi
