#!/usr/bin/env bash
# Write per-service deploy report JSON for the notify job.
# Env: SERVICE, SERVICE_LABEL, ENVIRONMENT, BUILD_VERSION, JOB_STATUS,
#      GITHUB_SHA, GITHUB_RUN_ID, GITHUB_REPOSITORY, GITHUB_SERVER_URL,
#      RENDER_SVC_ID (optional), SUBMODULE_SHA (optional), EC2_PATH (optional)
set -euo pipefail

OUT="${1:-deploy-report.json}"
SERVICE="${SERVICE:?SERVICE required}"
SERVICE_LABEL="${SERVICE_LABEL:-$SERVICE}"
ENVIRONMENT="${ENVIRONMENT:-unknown}"
BUILD_VERSION="${BUILD_VERSION:-unknown}"
JOB_STATUS="${JOB_STATUS:-unknown}"
RENDER_STATUS=""
RENDER_DEPLOY_ID=""
RENDER_SERVICE_ID="${RENDER_SVC_ID:-}"

if [[ -f "${RUNNER_TEMP:-/tmp}/render-deploy-outcome.json" ]]; then
  RENDER_STATUS="$(jq -r '.status // ""' "${RUNNER_TEMP}/render-deploy-outcome.json")"
  RENDER_DEPLOY_ID="$(jq -r '.deployId // ""' "${RUNNER_TEMP}/render-deploy-outcome.json")"
  if [[ -z "${RENDER_SERVICE_ID}" ]]; then
    RENDER_SERVICE_ID="$(jq -r '.serviceId // ""' "${RUNNER_TEMP}/render-deploy-outcome.json")"
  fi
elif [[ -f /tmp/render-deploy-id.txt ]]; then
  RENDER_DEPLOY_ID="$(cat /tmp/render-deploy-id.txt)"
fi

WORKFLOW_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

jq -n \
  --arg service "${SERVICE}" \
  --arg label "${SERVICE_LABEL}" \
  --arg environment "${ENVIRONMENT}" \
  --arg buildVersion "${BUILD_VERSION}" \
  --arg jobStatus "${JOB_STATUS}" \
  --arg commitSha "${GITHUB_SHA:-}" \
  --arg submoduleSha "${SUBMODULE_SHA:-}" \
  --arg renderStatus "${RENDER_STATUS}" \
  --arg renderDeployId "${RENDER_DEPLOY_ID}" \
  --arg renderServiceId "${RENDER_SERVICE_ID}" \
  --arg ec2Path "${EC2_PATH:-}" \
  --arg workflowUrl "${WORKFLOW_URL}" \
  --arg finishedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    service: $service,
    label: $label,
    environment: $environment,
    buildVersion: $buildVersion,
    jobStatus: $jobStatus,
    commitSha: $commitSha,
    submoduleSha: $submoduleSha,
    renderStatus: $renderStatus,
    renderDeployId: $renderDeployId,
    renderServiceId: $renderServiceId,
    ec2Path: $ec2Path,
    workflowUrl: $workflowUrl,
    finishedAt: $finishedAt
  }' > "${OUT}"

echo "Wrote deploy report: ${OUT}"
