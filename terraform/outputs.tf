output "server_public_ip" {
  description = "Public IPv4 address for the StatusPulse EC2 instance."
  value       = aws_instance.statuspulse.public_ip
}

output "server_public_dns" {
  description = "Public DNS name for the StatusPulse EC2 instance."
  value       = aws_instance.statuspulse.public_dns
}

output "ssh_command" {
  description = "SSH command using the configured custom port after Ansible hardening."
  value       = "ssh -p ${var.ssh_port} ubuntu@${aws_instance.statuspulse.public_ip}"
}
