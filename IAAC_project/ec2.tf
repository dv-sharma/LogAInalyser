resource "aws_instance" "ubuntu_test" {
  ami                         = var.ec2_ami
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.log_shipper.id
  vpc_security_group_ids      = [aws_security_group.log_shipper.id]
  key_name                    = var.ec2_key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.rstudio.name

  user_data = <<-USER_DATA
              #!/bin/bash
              set -euo pipefail

              CLOUDWATCH_DEB="/tmp/amazon-cloudwatch-agent.deb"
              wget -q -O "$CLOUDWATCH_DEB" https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
              dpkg -i "$CLOUDWATCH_DEB"

              cat <<'CONFIG' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              ${templatefile("${path.module}/code/cloudwatch-agent.json", {
                aws_region      = var.aws_region
                log_group_name  = aws_cloudwatch_log_group.syslog.name
                log_stream_name = var.cloudwatch_log_stream_name
              })}
              CONFIG

              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config \
                -m ec2 \
                -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
                -s
              USER_DATA

  tags = {
    Name = var.ec2_name_tag
  }

  lifecycle {
    prevent_destroy = true
  }
}
