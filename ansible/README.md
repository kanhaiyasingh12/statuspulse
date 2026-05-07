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
