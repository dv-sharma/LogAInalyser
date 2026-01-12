resource "aws_cloudwatch_log_group" "syslog" {
  name              = "syslog"
  retention_in_days = 0

  lifecycle {
    prevent_destroy = true
  }
}