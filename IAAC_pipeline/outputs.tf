
output "log_group_name" {
  value = aws_cloudwatch_log_group.syslog.name
}

output "instance_id" {
  value = aws_instance.log_shipper.id
}

output "public_ip" {
  value = aws_instance.log_shipper.public_ip
}