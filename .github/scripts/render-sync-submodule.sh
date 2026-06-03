#!/usr/bin/env bash
# Push a service submodule commit to its GitHub remote so Render (connected to that repo) can build it.
# Requires GH_PAT (recommended) or GITHUB_TOKEN with permission to push the service repo.
set -euo pipefail

SERVICE_PATH="${1:?Service path required (e.g. services/reviews)}"

GIT_TOKEN="${GH_PAT:-${GITHUB_TOKEN:-}}"
if [[ -z "${GIT_TOKEN}" ]]; then
  echo "::error::Set GitHub secret GH_PAT (PAT with contents:write on the service repo, e.g. reviews). GITHUB_TOKEN cannot push to other repos."
  exit 1
fi

if [[ ! -d "${SERVICE_PATH}/.git" ]]; then
  echo "Not a git repo: ${SERVICE_PATH} — skip sync"
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
  echo "::error::Unsupported origin URL: ${ORIGIN}"
  exit 1
fi

PUSH_URL="https://x-access-token:${GIT_TOKEN}@github.com/${REPO_PATH}.git"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config user.name "github-actions[bot]"

if git ls-remote "${PUSH_URL}" "refs/heads/${BRANCH}" 2>/dev/null | grep -qF "${SHA}"; then
  echo "Remote ${BRANCH} already contains ${SHA}"
  exit 0
fi

echo "Pushing ${SHA} → github.com/${REPO_PATH} (${BRANCH})…"
if ! git push "${PUSH_URL}" "HEAD:refs/heads/${BRANCH}"; then
  echo "::error::Push failed. Create fine-grained PAT secret GH_PAT on Serveaso repo with contents:write on ${REPO_PATH}."
  exit 1
fi

if ! git ls-remote "${PUSH_URL}" "refs/heads/${BRANCH}" 2>/dev/null | grep -qF "${SHA}"; then
  echo "::error::Push reported success but ${SHA} not found on origin/${BRANCH}."
  exit 1
fi

echo "Git push verified on remote."
