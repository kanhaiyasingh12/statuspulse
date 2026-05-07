variable "aws_region" {
  description = "AWS region for the EC2 instance."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for AWS resources."
  type        = string
  default     = "statuspulse"
}

variable "instance_type" {
  description = "EC2 instance type. t2.micro/t3.micro are typical free-tier choices where eligible."
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Existing AWS EC2 key pair name."
  type        = string
}

variable "ssh_port" {
  description = "Custom SSH port configured by Ansible."
  type        = number
  default     = 2222
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to the instance."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 20
}
