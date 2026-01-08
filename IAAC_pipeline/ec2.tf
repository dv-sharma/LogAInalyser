
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



resource "aws_instance" "log_shipper" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  # Optional SSH key
  key_name = var.ec2_key_name != "" ? var.ec2_key_name : null

  user_data = <<-USER_DATA
    #!/bin/bash
    set -euo pipefail

    export DEBIAN_FRONTEND=noninteractive

    # Basic tools
    apt-get update -y
    apt-get install -y wget ca-certificates

    # Install CloudWatch Agent (Ubuntu amd64)
    CLOUDWATCH_DEB="/tmp/amazon-cloudwatch-agent.deb"
    wget -q -O "$CLOUDWATCH_DEB" https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i "$CLOUDWATCH_DEB"

    # Write agent config (templated by Terraform)
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CONFIG'
    ${templatefile("${path.module}/code/cloudwatch-agent.json.tpl", {
      aws_region     = var.aws_region
      log_group_name = aws_cloudwatch_log_group.syslog.name
    })}
    CONFIG

    # Start agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
      -s

    # Generate a test syslog line
    logger "CW_AGENT_TEST: cloudwatch agent configured on $(hostname) at $(date -u)"
  USER_DATA

  tags = {
    Name = "${var.name_prefix}-log-shipper"
  }
}



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

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
