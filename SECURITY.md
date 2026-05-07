# Security

## Container Image Scanning

Use Trivy before and after fixes:

```bash
docker build -t statuspulse:scan .
trivy image statuspulse:scan
```

Remediation approach:

- Use `python:3.12-slim` instead of a full base image.
- Install only required runtime packages.
- Remove apt indexes after package installation.
- Keep Python dependencies pinned in `app/requirements.txt`.
- Rebuild regularly to pick up patched base images.

Record the before and after scan output in `screenshots/`.

## Secrets

No secrets should be committed.

- `.env` is listed in `.gitignore`.
- `.env.example` contains placeholders only.
- GitHub Actions deployment values must be stored in repository secrets.
- Server secrets live in `/opt/statuspulse/.env` with mode `0600`.

Verify with:

```bash
git log --all -- .env
git grep -n "password\\|secret\\|token\\|key"
```

## Runtime Hardening

- The application container runs as the `statuspulse` non-root user.
- PostgreSQL and Redis are isolated on a custom Docker network.
- Production exposes Nginx on ports `80` and `443`; Swarm app and Uptime Kuma ports are host-published locally for Nginx proxying.
- UFW allows only the custom SSH port, HTTP, and HTTPS.
- SSH root login and password authentication are disabled by Ansible.

## Reverse Proxy Headers

Configured in `nginx/statuspulse.https.conf`:

- `Strict-Transport-Security`
- `X-Content-Type-Options`
- `X-Frame-Options`
- `X-XSS-Protection`
- `Referrer-Policy`

Verify with:

```bash
curl -I https://YOUR_DOMAIN/
```

## Rate Limiting

The assessment requires `100` requests per minute per IP and a `429` demonstration.

Nginx uses:

```nginx
limit_req_zone $binary_remote_addr zone=statuspulse_api:10m rate=100r/m;
limit_req zone=statuspulse_api burst=20 nodelay;
```

Demo command:

```bash
for i in $(seq 1 120); do
  curl -s -o /dev/null -w "%{http_code}\n" https://YOUR_DOMAIN/health
done
```
