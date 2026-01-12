############################################
# Variables (edit defaults or use tfvars)
############################################
variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-2"
}

variable "name_prefix" {
  type        = string
  description = "Name prefix for resources"
  default     = "ai-log-demo"
}

variable "ec2_instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "ec2_key_name" {
  type        = string
  description = "Optional EC2 key pair name for SSH (leave empty to skip)"
  default     = ""
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR allowed to SSH (only used if ec2_key_name is set)"
  default     = "0.0.0.0/0"
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch Logs group name (keep 'syslog' to match your Python script)"
  default     = "syslogai"
}

variable "log_retention_days" {
  type        = number
  description = "Log retention in days"
  default     = 7
}