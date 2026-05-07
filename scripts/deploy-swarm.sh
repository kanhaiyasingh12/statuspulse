#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-${IMAGE:-}}"
APP_DIR="${APP_DIR:-/opt/statuspulse}"
ENV_FILE="${ENV_FILE:-$APP_DIR/.env}"
STACK_FILE="${STACK_FILE:-$APP_DIR/docker-stack.yml}"
STACK_NAME="${STACK_NAME:-statuspulse}"
HEALTH_URL="${HEALTH_URL:-https://${DOMAIN:-localhost}/health}"
LOG_FILE="${DEPLOY_LOG_FILE:-/var/log/statuspulse-deploy.log}"

log() {
  printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE"
}

if [ -z "$IMAGE" ]; then
  echo "Usage: $0 ghcr.io/owner/repo:tag" >&2
  exit 2
fi

cd "$APP_DIR"

previous_image=""
if [ -f "$ENV_FILE" ]; then
  previous_image="$(grep -E '^STATUSPULSE_IMAGE=' "$ENV_FILE" | cut -d= -f2- || true)"
fi

if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q active; then
  log "Initializing single-node Docker Swarm"
  docker swarm init
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
  if grep -q '^STATUSPULSE_IMAGE=' "$ENV_FILE"; then
    sed -i "s|^STATUSPULSE_IMAGE=.*|STATUSPULSE_IMAGE=$image|" "$ENV_FILE"
  else
    printf '\nSTATUSPULSE_IMAGE=%s\n' "$image" >> "$ENV_FILE"
  fi

  set -a
  . "$ENV_FILE"
  set +a
  docker stack deploy --with-registry-auth -c "$STACK_FILE" "$STACK_NAME"
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
docker pull "$IMAGE"

log "Deploying $IMAGE to stack $STACK_NAME"
deploy_image "$IMAGE"

if wait_for_health; then
  log "Swarm deployment succeeded for $IMAGE"
else
  log "Health check failed for $IMAGE"
  rollback
  exit 1
fi
