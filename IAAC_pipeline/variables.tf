variable "aws_region" {
  type        = string
  default     = "us-east-2"
  description = "AWS region"
}

variable "name_prefix" {
  type        = string
  default     = "syslog-sub"
  description = "Prefix for resource names"
}

variable "vpc_cidr" {
  type        = string
  default     = "172.31.0.0/16"
  description = "VPC CIDR"
}

variable "public_subnet_cidr" {
  type        = string
  default     = "172.31.16.0/20"
  description = "Public subnet CIDR"
}

variable "availability_zone" {
  type        = string
  default     = "us-east-2a"
  description = "AZ for public subnet"
}

variable "ec2_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type"
}

variable "ec2_key_name" {
  type        = string
  default     = ""
  description = "Optional EC2 key pair name for SSH. Leave empty to disable SSH key."
}

variable "ssh_ingress_cidrs" {
  type        = list(string)
  default     = []
  description = "Optional list of CIDRs allowed for SSH. Empty list = no SSH rule."
}

variable "log_group_name" {
  type        = string
  default     = "syslog"
  description = "CloudWatch log group name"
}

variable "log_retention_days" {
  type        = number
  default     = 7
  description = "CloudWatch log retention days"
}
variable "alert_email" {
  type        = string
  description = "Email address to receive alerts"
  default = "divyam.sharma3@gmail.com"
}


variable "bedrock_model_id" {
  type        = string
  description = "Bedrock model id to use"
  default     = "mistral.mistral-large-3-675b-instruct"
}
