#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-}"
ACME_EMAIL="${ACME_EMAIL:-}"
NGINX_AVAILABLE="${NGINX_AVAILABLE:-/etc/nginx/sites-available/statuspulse}"
NGINX_ENABLED="${NGINX_ENABLED:-/etc/nginx/sites-enabled/statuspulse}"
APP_DIR="${APP_DIR:-/opt/statuspulse}"

if [ -z "$DOMAIN" ] || [ -z "$ACME_EMAIL" ]; then
  echo "Set DOMAIN and ACME_EMAIL before running this script." >&2
  exit 2
fi

mkdir -p /var/www/certbot

sed "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$APP_DIR/nginx/statuspulse.http.conf" > "$NGINX_AVAILABLE"
ln -sf "$NGINX_AVAILABLE" "$NGINX_ENABLED"
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
  certbot certonly --webroot \
    -w /var/www/certbot \
    -d "$DOMAIN" \
    --email "$ACME_EMAIL" \
    --agree-tos \
    --non-interactive
fi

sed "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$APP_DIR/nginx/statuspulse.https.conf" > "$NGINX_AVAILABLE"
nginx -t
systemctl reload nginx
