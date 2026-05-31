#!/usr/bin/env bash
# Versioned Node.js deploy to EC2 with pm2. Keeps last KEEP_RELEASES for rollback.
set -euo pipefail

SERVICE="${SERVICE:?SERVICE required}"
SERVICE_PATH="${SERVICE_PATH:?SERVICE_PATH required}"
EC2_HOST="${EC2_HOST:?EC2_HOST required}"
EC2_USER="${EC2_USER:?EC2_USER required}"
EC2_SSH_KEY="${EC2_SSH_KEY:?EC2_SSH_KEY required}"
DEPLOY_ROOT="${DEPLOY_ROOT:-/home/ubuntu/${SERVICE}}"
BUILD_VERSION="${BUILD_VERSION:?BUILD_VERSION required}"
KEEP_RELEASES="${KEEP_RELEASES:-5}"
INSTALL_CMD="${INSTALL_CMD:-npm ci --omit=dev}"
PM2_APP="${PM2_APP:-${SERVICE}}"
PM2_SCRIPT="${PM2_SCRIPT:-}"

ENV_FILE_LOCAL="${ENV_FILE_LOCAL:-}"

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes)

setup_ssh() {
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  printf '%s\n' "${EC2_SSH_KEY}" > ~/.ssh/deploy_key
  chmod 600 ~/.ssh/deploy_key
  ssh-keyscan -H "${EC2_HOST}" >> ~/.ssh/known_hosts 2>/dev/null || true
}

ssh_cmd() {
  ssh "${SSH_OPTS[@]}" -i ~/.ssh/deploy_key "${EC2_USER}@${EC2_HOST}" "$@"
}

rsync_to_staging() {
  local staging_dir="$1"
  rsync -az --delete \
    -e "ssh ${SSH_OPTS[*]} -i ~/.ssh/deploy_key" \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude '.env' \
    --exclude '.env.*' \
    --exclude 'logs' \
    "${SERVICE_PATH}/" "${EC2_USER}@${EC2_HOST}:${staging_dir}/"
}

echo "Deploying ${SERVICE} v${BUILD_VERSION} to ${EC2_USER}@${EC2_HOST}:${DEPLOY_ROOT}"

setup_ssh

STAGING="/tmp/deploy-${SERVICE}-${BUILD_VERSION}-$$"
RELEASE_DIR="${DEPLOY_ROOT}/releases/${BUILD_VERSION}"

ssh_cmd "mkdir -p '${DEPLOY_ROOT}/releases' '${STAGING}'"
rsync_to_staging "${STAGING}"

if [[ -n "${ENV_FILE_LOCAL}" && -f "${ENV_FILE_LOCAL}" && -s "${ENV_FILE_LOCAL}" ]]; then
  scp "${SSH_OPTS[@]}" -i ~/.ssh/deploy_key "${ENV_FILE_LOCAL}" \
    "${EC2_USER}@${EC2_HOST}:${STAGING}/.env"
else
  echo "No PROD_ENV_* secret content; keeping existing .env on server if present."
fi

ssh_cmd bash -s <<REMOTE
set -euo pipefail
SERVICE="${SERVICE}"
STAGING="${STAGING}"
RELEASE_DIR="${RELEASE_DIR}"
DEPLOY_ROOT="${DEPLOY_ROOT}"
BUILD_VERSION="${BUILD_VERSION}"
KEEP_RELEASES="${KEEP_RELEASES}"
INSTALL_CMD="${INSTALL_CMD}"
PM2_APP="${PM2_APP}"
PM2_SCRIPT="${PM2_SCRIPT}"

rm -rf "\${RELEASE_DIR}"
mkdir -p "\${RELEASE_DIR}"
rsync -a "\${STAGING}/" "\${RELEASE_DIR}/"
rm -rf "\${STAGING}"

cd "\${RELEASE_DIR}"
echo "Running install: \${INSTALL_CMD}"
eval "\${INSTALL_CMD}"

ln -sfn "\${RELEASE_DIR}" "\${DEPLOY_ROOT}/current"
echo "\${BUILD_VERSION}" > "\${DEPLOY_ROOT}/VERSION"
echo "\${BUILD_VERSION}" > "\${RELEASE_DIR}/BUILD_VERSION"
date -u +"%Y-%m-%dT%H:%M:%SZ" > "\${DEPLOY_ROOT}/DEPLOYED_AT"

cd "\${DEPLOY_ROOT}/current"

if [[ -f ecosystem.config.js ]]; then
  if pm2 describe "\${PM2_APP}" >/dev/null 2>&1; then
    pm2 startOrReload ecosystem.config.js --only "\${PM2_APP}" --update-env
  else
    pm2 start ecosystem.config.js --only "\${PM2_APP}"
  fi
elif [[ -n "\${PM2_SCRIPT}" ]]; then
  if pm2 describe "\${PM2_APP}" >/dev/null 2>&1; then
    pm2 delete "\${PM2_APP}" || true
  fi
  pm2 start "\${PM2_SCRIPT}" --name "\${PM2_APP}" --cwd "\${DEPLOY_ROOT}/current"
else
  echo "No ecosystem.config.js or PM2_SCRIPT; set PM2_SCRIPT for \${SERVICE}"
  exit 1
fi

pm2 save

cd "\${DEPLOY_ROOT}/releases"
ls -1t | tail -n +\$((KEEP_RELEASES + 1)) | while read -r old; do
  [[ -n "\${old}" ]] && rm -rf "\${old}"
done

echo "Active release: \$(cat \${DEPLOY_ROOT}/VERSION)"
REMOTE

echo "EC2 deploy complete: ${SERVICE} @ ${BUILD_VERSION}"
