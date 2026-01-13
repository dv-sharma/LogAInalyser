############################################

terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}


############################################
# Provider
############################################
provider "aws" {
  region = var.aws_region
}

############################################
# Networking: VPC + Public Subnet
############################################
resource "aws_vpc" "this" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.20.1.0/24"
  map_public_ip_on_launch = true

  tags = { Name = "${var.name_prefix}-public-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

############################################
# Security Group
############################################
resource "aws_security_group" "ec2" {
  name        = "${var.name_prefix}-sg"
  description = "EC2 security group"
  vpc_id      = aws_vpc.this.id

  # SSH only if key_name is set
  ingress {
    description = "SSH (for EC2 Instance Connect / SSH)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-sg" }
}

############################################
# CloudWatch Log Group (must match your script)
############################################
resource "aws_cloudwatch_log_group" "syslog" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days

  tags = { Name = "${var.name_prefix}-loggroup" }
}

############################################
# IAM Role + Instance Profile
############################################
resource "aws_iam_role" "ec2_role" {
  name = "${var.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# For CloudWatch Agent to ship logs
resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Inline policy: allow Bedrock invoke + allow reading logs (FilterLogEvents) if you run your polling script on this EC2
resource "aws_iam_role_policy" "bedrock_and_logs_read" {
  name = "${var.name_prefix}-bedrock-and-logs-read"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "BedrockInvoke",
        Effect = "Allow",
        Action = [
          "bedrock:InvokeModel"
        ],
        Resource = "*"
      },
      {
        Sid    = "ReadLogsForPolling",
        Effect = "Allow",
        Action = [
          "logs:FilterLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

############################################
# Ubuntu AMI lookup
############################################
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############################################
# EC2 Instance + CloudWatch Agent setup
############################################
resource "aws_instance" "log_shipper" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  key_name = var.ec2_key_name != "" ? var.ec2_key_name : null

  user_data = <<-USER_DATA
    #!/bin/bash
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
    apt-get install -y wget ca-certificates
    apt-get install python3-pip -y
    pip install boto3
    apt install nginx -y

    # Install CloudWatch Agent (Ubuntu amd64)
    CLOUDWATCH_DEB="/tmp/amazon-cloudwatch-agent.deb"
    wget -q -O "$CLOUDWATCH_DEB" https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i "$CLOUDWATCH_DEB"

    # Write agent config
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CONFIG'
    {
      "agent": {
        "region": "${var.aws_region}"
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/syslog",
                "log_group_name": "${aws_cloudwatch_log_group.syslog.name}",
                "log_stream_name": "{instance_id}/syslog",
                "timestamp_format": "%b %d %H:%M:%S"
              }
            ]
          }
        }
      }
    }
    CONFIG

    # Start agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
      -s

    # Emit a test log line to verify ingestion
    logger "CW_AGENT_TEST: cloudwatch agent configured on $(hostname) at $(date -u)"
  USER_DATA

  tags = {
    Name = "${var.name_prefix}-log-shipper"
  }
}

############################################
# Outputs
############################################
output "log_group_name" {
  value = aws_cloudwatch_log_group.syslog.name
}

output "ec2_public_ip" {
  value = aws_instance.log_shipper.public_ip
}

output "ec2_instance_id" {
  value = aws_instance.log_shipper.id
}

output "ec2_role_name" {
  value = aws_iam_role.ec2_role.name
}
