variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "172.31.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "172.31.16.0/20"
}

variable "availability_zone" {
  description = "Availability zone for the subnet."
  type        = string
  default     = "us-east-1b"
}

variable "ec2_ami" {
  description = "AMI ID for the log shipper instance."
  type        = string
  default     = "ami-0e1bed4f06a3b463d"
}

variable "ec2_instance_type" {
  description = "Instance type for the log shipper instance."
  type        = string
  default     = "t2.xlarge"
}

variable "ec2_key_name" {
  description = "EC2 key pair name for SSH access."
  type        = string
  default     = "testubuntu"
}

variable "sns_notification_email" {
  description = "Email address to subscribe to syslog error notifications."
  type        = string
  default     = "divyam.sharma3@gmail.com"
}

variable "ec2_name_tag" {
  description = "Name tag for the EC2 instance."
  type        = string
  default     = "ubuntu-test"
}

variable "cloudwatch_log_stream_name" {
  description = "CloudWatch log stream name pattern for syslog."
  type        = string
  default     = "{instance_id}"
}
