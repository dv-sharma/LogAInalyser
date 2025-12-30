resource "aws_instance" "ubuntu_test" {
  ami                         = var.ec2_ami
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.log_shipper.id
  vpc_security_group_ids      = [aws_security_group.log_shipper.id]
  key_name                    = var.ec2_key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.rstudio.name

  tags = {
    Name = "ubuntu-test"
  }

  lifecycle {
    prevent_destroy = true
  }
}
