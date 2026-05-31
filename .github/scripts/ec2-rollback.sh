#!/usr/bin/env bash
# Roll back an EC2 Node/Docker service to a previous release folder.
set -euo pipefail

SERVICE="${SERVICE:?SERVICE required}"
EC2_HOST="${EC2_HOST:?EC2_HOST required}"
EC2_USER="${EC2_USER:?EC2_USER required}"
EC2_SSH_KEY="${EC2_SSH_KEY:?EC2_SSH_KEY required}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"
DEPLOY_ROOT="${DEPLOY_ROOT:-/home/ubuntu/${SERVICE}}"
PM2_APP="${PM2_APP:-${SERVICE}}"
DOCKER="${DOCKER:-false}"

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes)

mkdir -p ~/.ssh
chmod 700 ~/.ssh
printf '%s\n' "${EC2_SSH_KEY}" > ~/.ssh/deploy_key
chmod 600 ~/.ssh/deploy_key
ssh-keyscan -H "${EC2_HOST}" >> ~/.ssh/known_hosts 2>/dev/null || true

ssh "${SSH_OPTS[@]}" -i ~/.ssh/deploy_key "${EC2_USER}@${EC2_HOST}" bash -s <<REMOTE
set -euo pipefail
SERVICE="${SERVICE}"
DEPLOY_ROOT="${DEPLOY_ROOT}"
ROLLBACK_VERSION="${ROLLBACK_VERSION}"
PM2_APP="${PM2_APP}"
DOCKER="${DOCKER}"

if [[ ! -d "\${DEPLOY_ROOT}/releases" ]]; then
  echo "No releases directory at \${DEPLOY_ROOT}/releases"
  exit 1
fi

if [[ -z "\${ROLLBACK_VERSION}" ]]; then
  CURRENT="\$(readlink -f "\${DEPLOY_ROOT}/current" 2>/dev/null || true)"
  ROLLBACK_VERSION="\$(ls -1t "\${DEPLOY_ROOT}/releases" | grep -v "\$(basename "\${CURRENT}")" | head -n 1 || true)"
fi

if [[ -z "\${ROLLBACK_VERSION}" ]]; then
  echo "Could not determine rollback version. Pass rollback_version explicitly."
  ls -1t "\${DEPLOY_ROOT}/releases" || true
  exit 1
fi

TARGET="\${DEPLOY_ROOT}/releases/\${ROLLBACK_VERSION}"
if [[ ! -d "\${TARGET}" ]]; then
  echo "Release not found: \${TARGET}"
  ls -1t "\${DEPLOY_ROOT}/releases" || true
  exit 1
fi

ln -sfn "\${TARGET}" "\${DEPLOY_ROOT}/current"
echo "\${ROLLBACK_VERSION}" > "\${DEPLOY_ROOT}/VERSION"
date -u +"%Y-%m-%dT%H:%M:%SZ" > "\${DEPLOY_ROOT}/DEPLOYED_AT"

cd "\${DEPLOY_ROOT}/current"

if [[ "\${DOCKER}" == "true" ]]; then
  docker compose up -d --remove-orphans app
elif [[ -f ecosystem.config.js ]]; then
  pm2 startOrReload ecosystem.config.js --only "\${PM2_APP}" --update-env
else
  pm2 restart "\${PM2_APP}" || pm2 start "\${PM2_APP}"
fi

pm2 save 2>/dev/null || true
echo "Rolled back \${SERVICE} to \${ROLLBACK_VERSION}"
REMOTE

echo "Rollback complete: ${SERVICE} -> ${ROLLBACK_VERSION:-previous}"
