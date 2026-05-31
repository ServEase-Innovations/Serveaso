#!/usr/bin/env bash
# Versioned Docker deploy for providers service on EC2.
set -euo pipefail

SERVICE_PATH="${SERVICE_PATH:?SERVICE_PATH required}"
EC2_HOST="${EC2_HOST:?EC2_HOST required}"
EC2_USER="${EC2_USER:?EC2_USER required}"
EC2_SSH_KEY="${EC2_SSH_KEY:?EC2_SSH_KEY required}"
DEPLOY_ROOT="${DEPLOY_ROOT:-/home/ubuntu/providers}"
BUILD_VERSION="${BUILD_VERSION:?BUILD_VERSION required}"
KEEP_RELEASES="${KEEP_RELEASES:-5}"

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes)

mkdir -p ~/.ssh
chmod 700 ~/.ssh
printf '%s\n' "${EC2_SSH_KEY}" > ~/.ssh/deploy_key
chmod 600 ~/.ssh/deploy_key
ssh-keyscan -H "${EC2_HOST}" >> ~/.ssh/known_hosts 2>/dev/null || true

STAGING="/tmp/deploy-providers-${BUILD_VERSION}-$$"
RELEASE_DIR="${DEPLOY_ROOT}/releases/${BUILD_VERSION}"

ssh "${SSH_OPTS[@]}" -i ~/.ssh/deploy_key "${EC2_USER}@${EC2_HOST}" \
  "mkdir -p '${DEPLOY_ROOT}/releases' '${STAGING}'"

rsync -az --delete \
  -e "ssh ${SSH_OPTS[*]} -i ~/.ssh/deploy_key" \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude '.env' \
  --exclude '.env.*' \
  "${SERVICE_PATH}/" "${EC2_USER}@${EC2_HOST}:${STAGING}/"

ssh "${SSH_OPTS[@]}" -i ~/.ssh/deploy_key "${EC2_USER}@${EC2_HOST}" bash -s <<REMOTE
set -euo pipefail
STAGING="${STAGING}"
RELEASE_DIR="${RELEASE_DIR}"
DEPLOY_ROOT="${DEPLOY_ROOT}"
BUILD_VERSION="${BUILD_VERSION}"
KEEP_RELEASES="${KEEP_RELEASES}"

rm -rf "\${RELEASE_DIR}"
mkdir -p "\${RELEASE_DIR}"
rsync -a "\${STAGING}/" "\${RELEASE_DIR}/"
rm -rf "\${STAGING}"

cd "\${RELEASE_DIR}"
docker compose build --no-cache app
docker compose up -d --remove-orphans app

ln -sfn "\${RELEASE_DIR}" "\${DEPLOY_ROOT}/current"
echo "\${BUILD_VERSION}" > "\${DEPLOY_ROOT}/VERSION"
date -u +"%Y-%m-%dT%H:%M:%SZ" > "\${DEPLOY_ROOT}/DEPLOYED_AT"

cd "\${DEPLOY_ROOT}/releases"
ls -1t | tail -n +\$((KEEP_RELEASES + 1)) | while read -r old; do
  [[ -n "\${old}" ]] && rm -rf "\${old}"
done

echo "Providers active: \$(cat \${DEPLOY_ROOT}/VERSION)"
REMOTE

echo "Providers EC2 deploy complete @ ${BUILD_VERSION}"
