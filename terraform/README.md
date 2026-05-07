# AWS EC2 Terraform

This creates a single Ubuntu EC2 instance and a security group for StatusPulse.

## Usage

```bash
terraform init
terraform plan -var="key_name=YOUR_AWS_KEYPAIR"
terraform apply -var="key_name=YOUR_AWS_KEYPAIR"
```

## GitHub Actions Workflow

The repo includes `.github/workflows/terraform.yml`.

It runs:

- `terraform fmt -check`
- `terraform init`
- `terraform validate`
- `terraform plan`

It only applies when manually triggered with `apply=true` from the GitHub Actions UI.

Required GitHub repository secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_KEY_NAME
ALLOWED_SSH_CIDRS
```

Recommended repository variable:

```text
AWS_REGION=us-east-1
```

`ALLOWED_SSH_CIDRS` must be a Terraform list string, for example:

```text
["203.0.113.10/32"]
```

After apply, copy `server_public_ip` and create a GoDaddy DNS `A` record:

```text
Type: A
Name: @ or status
Value: <server_public_ip>
TTL: 600
```

Then run the Ansible playbook against the instance.

## Notes

- Restrict `allowed_ssh_cidrs` to your public IP before final submission.
- The default instance type is `t2.micro`; confirm AWS free-tier eligibility in your account and region.
- This Terraform intentionally leaves DNS manual because GoDaddy API credentials should not be needed for the assessment.
