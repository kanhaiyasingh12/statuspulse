#!/usr/bin/env bash
set -euo pipefail

HEALTH_URL="${HEALTH_URL:-https://${DOMAIN:-example.com}/health}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
LOG_FILE="${MONITOR_LOG_FILE:-/var/log/statuspulse-monitor.log}"
EXPECTED_SERVICES="${EXPECTED_SERVICES:-statuspulse_app statuspulse_postgres statuspulse_redis statuspulse_uptime-kuma}"
TLS_HOST="${TLS_HOST:-${DOMAIN:-example.com}}"

log() {
  printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE"
}

alert() {
  local message="$1"
  log "ALERT $message"
  if [ -n "$ALERT_WEBHOOK_URL" ] && command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 10 -X POST -H 'Content-Type: application/json' \
      --data "{\"text\":\"StatusPulse alert: $message\"}" \
      "$ALERT_WEBHOOK_URL" >/dev/null || log "Webhook alert failed"
  fi
}

if ! command -v curl >/dev/null 2>&1; then
  log "curl is missing"
  exit 0
fi

health_body="$(mktemp)"
health_code="$(curl -sS --max-time 10 -o "$health_body" -w '%{http_code}' "$HEALTH_URL" || true)"
if [ "$health_code" != "200" ]; then
  alert "health endpoint returned HTTP $health_code"
else
  if ! python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); assert "status" in data and "checks" in data' "$health_body" 2>/dev/null; then
    alert "health endpoint returned invalid JSON"
  else
    log "health endpoint OK"
  fi
fi
rm -f "$health_body"

disk_pct="$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')"
if [ "${disk_pct:-0}" -gt 80 ]; then
  alert "disk usage is ${disk_pct}%"
else
  log "disk usage OK at ${disk_pct}%"
fi

mem_pct="$(free | awk '/Mem:/ {printf "%.0f", ($3/$2)*100}')"
if [ "${mem_pct:-0}" -gt 90 ]; then
  alert "memory usage is ${mem_pct}%"
else
  log "memory usage OK at ${mem_pct}%"
fi

if command -v docker >/dev/null 2>&1; then
  for service in $EXPECTED_SERVICES; do
    replicas="$(docker service ls --filter "name=$service" --format '{{.Replicas}}' 2>/dev/null | head -n 1 || true)"
    if [ -z "$replicas" ] || ! printf '%s' "$replicas" | awk -F/ '{exit !($1 == $2 && $2 > 0)}'; then
      alert "swarm service $service is not healthy: ${replicas:-missing}"
    else
      log "swarm service $service OK: $replicas"
    fi
  done
else
  alert "docker command is missing"
fi

if command -v openssl >/dev/null 2>&1; then
  expiry_epoch="$(
    echo | openssl s_client -servername "$TLS_HOST" -connect "$TLS_HOST:443" 2>/dev/null \
      | openssl x509 -noout -enddate 2>/dev/null \
      | cut -d= -f2 \
      | xargs -I{} date -d "{}" +%s 2>/dev/null || true
  )"
  if [ -n "$expiry_epoch" ]; then
    now_epoch="$(date +%s)"
    days_left="$(( (expiry_epoch - now_epoch) / 86400 ))"
    if [ "$days_left" -lt 14 ]; then
      alert "TLS certificate expires in ${days_left} days"
    else
      log "TLS certificate OK with ${days_left} days remaining"
    fi
  else
    alert "could not inspect TLS certificate for $TLS_HOST"
  fi
fi
