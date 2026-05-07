#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/statuspulse}"
BACKUP_DIR="${BACKUP_DIR:-$APP_DIR/backups}"
ENV_FILE="${ENV_FILE:-$APP_DIR/.env}"
LOG_FILE="${BACKUP_LOG_FILE:-/var/log/statuspulse-backup.log}"
RETENTION="${BACKUP_RETENTION:-7}"
POSTGRES_SERVICE="${POSTGRES_SERVICE:-statuspulse_postgres}"

log() {
  printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE"
}

mkdir -p "$BACKUP_DIR"
cd "$APP_DIR"

if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

timestamp="$(date +%F_%H%M%S)"
backup_file="$BACKUP_DIR/statuspulse_db_${timestamp}.sql.gz"

postgres_container="$(docker ps --filter "name=${POSTGRES_SERVICE}" --format '{{.ID}}' | head -n 1)"
if [ -z "$postgres_container" ]; then
  log "No running PostgreSQL container found for service $POSTGRES_SERVICE"
  exit 1
fi

log "Starting PostgreSQL backup to $backup_file"
docker exec "$postgres_container" \
  pg_dump -U "${DB_USER:-statuspulse}" "${DB_NAME:-statuspulse}" \
  | gzip > "$backup_file"
log "Backup completed: $backup_file"

find "$BACKUP_DIR" -name 'statuspulse_db_*.sql.gz' -type f \
  | sort -r \
  | tail -n "+$((RETENTION + 1))" \
  | while read -r old_backup; do
      rm -f "$old_backup"
      log "Removed old backup $old_backup"
    done

if [ -n "${S3_BUCKET:-}" ]; then
  if command -v aws >/dev/null 2>&1; then
    aws s3 cp "$backup_file" "s3://$S3_BUCKET/"
    log "Uploaded backup to s3://$S3_BUCKET/"
  else
    log "S3_BUCKET set but aws CLI is not installed"
  fi
fi
