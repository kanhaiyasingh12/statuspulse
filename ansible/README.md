# StatusPulse Ansible

This playbook configures a fresh Ubuntu EC2 VM for StatusPulse using Docker Swarm, PostgreSQL, MySQL, Redis, Nginx, Certbot, Uptime Kuma, and Slack-compatible webhook alerts.

## Usage

1. Copy the inventory:

   ```bash
   cp inventory.example.ini inventory.ini
   ```

2. Edit `inventory.ini` and `vars.yml`.

   Use the EC2 public IP for `ansible_host` when running from GitHub Actions or any machine outside the VPC. The private IP only works from inside the same VPC, a VPN, or a bastion host.

   Keep `ansible_port` aligned with `deploy_ssh_port` in `vars.yml`. The default is `22` so the playbook can run through the existing EC2 SSH rule. If you change `deploy_ssh_port`, open that port in the EC2 security group before the next run.

3. Install the required collection:

   ```bash
   ansible-galaxy collection install community.general
   ```

4. Run the playbook:

   ```bash
   ansible-playbook -i inventory.ini playbook.yml
   ```

5. Run it a second time and capture the summary for idempotency proof. After the first successful run, the playbook should report no changes unless files, variables, certificates, firewall rules, cron jobs, or service state changed.

Before running Certbot, create a GoDaddy `A` record pointing your domain or subdomain to the EC2 public IP.

The playbook performs:

- Docker and Compose installation
- SSH hardening, UFW firewall rules, swap, and unattended upgrades
- Docker Swarm initialization
- StatusPulse, PostgreSQL, MySQL, Redis, and Uptime Kuma stack deployment
- Nginx reverse proxy and Let's Encrypt TLS setup through `scripts/bootstrap-certbot.sh`
- Health monitor and database backup cron jobs

## GitHub Actions

`.github/workflows/ansible.yml` runs a syntax check and minimal `ansible-lint` validation when Ansible, Nginx, stack, script, or workflow files change.

To run the playbook from GitHub Actions, start the `Ansible` workflow manually and set `apply` to `true`. Configure these repository secrets first:

```text
ANSIBLE_HOST
ANSIBLE_USER
ANSIBLE_SSH_KEY
ANSIBLE_PORT
ANSIBLE_DEPLOY_USER
ANSIBLE_DEPLOY_SSH_PORT
STATUSPULSE_DOMAIN
ACME_EMAIL
STATUSPULSE_IMAGE
DB_NAME
DB_USER
DB_PASSWORD
MYSQL_DATABASE
MYSQL_USER
MYSQL_PASSWORD
MYSQL_ROOT_PASSWORD
ALERT_WEBHOOK_URL
SLACK_WEBHOOK_URL
```
