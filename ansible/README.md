# StatusPulse Ansible

This playbook configures a fresh Ubuntu EC2 VM for StatusPulse using Docker Swarm, Nginx, Certbot, and Slack-compatible webhook alerts.

## Usage

1. Copy the inventory:

   ```bash
   cp inventory.example.ini inventory.ini
   ```

2. Edit `inventory.ini` and `vars.yml`.

3. Install the required collection:

   ```bash
   ansible-galaxy collection install community.general
   ```

4. Run the playbook:

   ```bash
   ansible-playbook -i inventory.ini playbook.yml
   ```

5. Run it a second time and capture the summary for idempotency proof. Most tasks should report no changes after the first successful run.

Before running Certbot, create a GoDaddy `A` record pointing your domain or subdomain to the EC2 public IP.

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
ALERT_WEBHOOK_URL
SLACK_WEBHOOK_URL
```
