#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-${IMAGE:-}}"
APP_DIR="${APP_DIR:-/opt/statuspulse}"
ENV_FILE="${ENV_FILE:-$APP_DIR/.env}"
STACK_FILE="${STACK_FILE:-$APP_DIR/docker-stack.yml}"
STACK_NAME="${STACK_NAME:-statuspulse}"
HEALTH_URL="${HEALTH_URL:-https://${DOMAIN:-localhost}/health}"
LOG_FILE="${DEPLOY_LOG_FILE:-/var/log/statuspulse-deploy.log}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
STACK_ENV_VARS=(
  STATUSPULSE_IMAGE
  DB_NAME
  DB_USER
  DB_PASSWORD
  REDIS_PASSWORD
  MYSQL_DATABASE
  MYSQL_USER
  MYSQL_PASSWORD
  MYSQL_ROOT_PASSWORD
)

if ! touch "$LOG_FILE" >/dev/null 2>&1; then
  LOG_FILE="$APP_DIR/statuspulse-deploy.log"
  touch "$LOG_FILE"
fi

log() {
  printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE"
}

if [ -z "$IMAGE" ]; then
  echo "Usage: $0 ghcr.io/owner/repo:tag" >&2
  exit 2
fi

cd "$APP_DIR"

if ! command -v "${DOCKER_BIN%% *}" >/dev/null 2>&1; then
  log "Docker command not found: ${DOCKER_BIN%% *}"
  exit 1
fi

previous_image=""
if [ -f "$ENV_FILE" ]; then
  previous_image="$(grep -E '^STATUSPULSE_IMAGE=' "$ENV_FILE" | cut -d= -f2- || true)"
fi

if ! $DOCKER_BIN info --format '{{.Swarm.LocalNodeState}}' | grep -q active; then
  log "Initializing single-node Docker Swarm"
  $DOCKER_BIN swarm init
fi

wait_for_health() {
  for _ in $(seq 1 36); do
    if curl -fsS --max-time 5 "$HEALTH_URL" | grep -q '"status":"healthy"'; then
      return 0
    fi
    sleep 5
  done
  return 1
}

deploy_image() {
  local image="$1"
  local env_name
  local env_args=()
  if grep -q '^STATUSPULSE_IMAGE=' "$ENV_FILE"; then
    sed -i "s|^STATUSPULSE_IMAGE=.*|STATUSPULSE_IMAGE=$image|" "$ENV_FILE"
  else
    printf '\nSTATUSPULSE_IMAGE=%s\n' "$image" >> "$ENV_FILE"
  fi

  set -a
  . "$ENV_FILE"
  set +a
  if [ "${DOCKER_BIN%% *}" = "sudo" ]; then
    for env_name in "${STACK_ENV_VARS[@]}"; do
      env_args+=("${env_name}=${!env_name:-}")
    done
    sudo env "${env_args[@]}" docker stack deploy --with-registry-auth -c "$STACK_FILE" "$STACK_NAME"
  else
    $DOCKER_BIN stack deploy --with-registry-auth -c "$STACK_FILE" "$STACK_NAME"
  fi
}

rollback() {
  if [ -n "$previous_image" ]; then
    log "Rolling back to $previous_image"
    deploy_image "$previous_image"
    wait_for_health || log "Rollback health check failed"
  else
    log "No previous image found; rollback skipped"
  fi
}

log "Pulling $IMAGE"
$DOCKER_BIN pull "$IMAGE"

log "Deploying $IMAGE to stack $STACK_NAME"
deploy_image "$IMAGE"

if wait_for_health; then
  log "Swarm deployment succeeded for $IMAGE"
else
  log "Health check failed for $IMAGE"
  rollback
  exit 1
fi
