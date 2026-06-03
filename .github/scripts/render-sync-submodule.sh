#!/usr/bin/env bash
# Push a service submodule commit to its GitHub remote so Render (connected to that repo) can build it.
# Requires: GITHUB_TOKEN with push access to the service repo (deploy job: contents: write).
set -euo pipefail

SERVICE_PATH="${1:?Service path required (e.g. services/reviews)}"

if [[ ! -d "${SERVICE_PATH}/.git" ]]; then
  echo "Not a git repo: ${SERVICE_PATH} — skip sync"
  exit 0
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "::warning::GITHUB_TOKEN not set — cannot push ${SERVICE_PATH} to GitHub. Render may deploy an old commit."
  exit 0
fi

cd "${SERVICE_PATH}"
BRANCH="${RENDER_DEPLOY_BRANCH:-main}"
SHA="$(git rev-parse HEAD)"
echo "Service repo ${SERVICE_PATH} @ ${SHA} (branch ${BRANCH})"

ORIGIN="$(git remote get-url origin)"
REPO_PATH=""
if [[ "${ORIGIN}" =~ ^https://github.com/(.+)\.git$ ]]; then
  REPO_PATH="${BASH_REMATCH[1]}"
elif [[ "${ORIGIN}" =~ ^git@github.com:(.+)\.git$ ]]; then
  REPO_PATH="${BASH_REMATCH[1]}"
else
  echo "::warning::Unsupported origin URL: ${ORIGIN} — push manually to trigger Render."
  exit 0
fi

PUSH_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_PATH}.git"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config user.name "github-actions[bot]"

if git ls-remote "${PUSH_URL}" "refs/heads/${BRANCH}" 2>/dev/null | grep -qF "${SHA}"; then
  echo "Remote ${BRANCH} already at ${SHA} — no push needed"
  exit 0
fi

echo "Pushing ${SHA} to github.com/${REPO_PATH} (${BRANCH}) for Render…"
git push "${PUSH_URL}" "HEAD:refs/heads/${BRANCH}"
echo "Git push complete."
