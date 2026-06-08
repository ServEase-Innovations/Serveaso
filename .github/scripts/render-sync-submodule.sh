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

mirror_remote_for_path() {
  case "$1" in
    services/imageUploader) echo "ServEase-Innovations/imageUploader" ;;
    *) echo "" ;;
  esac
}

mirror_push_folder_to_repo() {
  local SRC="$1"
  local REPO_PATH="$2"
  local BRANCH="${RENDER_DEPLOY_BRANCH:-main}"
  local PUSH_URL="https://x-access-token:${GIT_TOKEN}@github.com/${REPO_PATH}.git"
  local WORK
  WORK="$(mktemp -d)"

  if git ls-remote "${PUSH_URL}" "refs/heads/${BRANCH}" >/dev/null 2>&1; then
    git clone --depth 1 -b "${BRANCH}" "${PUSH_URL}" "${WORK}"
  else
    git clone --depth 1 "${PUSH_URL}" "${WORK}"
  fi

  rsync -a \
    --exclude node_modules \
    --exclude .env \
    --exclude '.env.*' \
    --exclude .git \
    "${SRC}/" "${WORK}/"

  cd "${WORK}"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git config user.name "github-actions[bot]"
  git add -A

  if git diff --staged --quiet; then
    echo "Mirror sync: no file changes for ${REPO_PATH}"
    return 0
  fi

  git commit -m "Sync from Serveaso monorepo (${GITHUB_SHA:-manual deploy})"
  git push "${PUSH_URL}" "HEAD:${BRANCH}"
  echo "Mirror push verified for github.com/${REPO_PATH}"
}

if [[ ! -d "${SERVICE_PATH}/.git" ]]; then
  REMOTE_REPO="$(mirror_remote_for_path "${SERVICE_PATH}")"
  if [[ -n "${REMOTE_REPO}" ]]; then
    echo "Mirroring ${SERVICE_PATH} → github.com/${REMOTE_REPO} (no nested .git in CI checkout)"
    mirror_push_folder_to_repo "${SERVICE_PATH}" "${REMOTE_REPO}"
    exit 0
  fi
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
