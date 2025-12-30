resource "aws_cloudwatch_log_metric_filter" "syslog_error_filter" {
  name           = "Syslog_Error_Filter"
  log_group_name = aws_cloudwatch_log_group.syslog.name
  pattern        = "?fail ?failed ?error ?denied ?unauthorized ?invalid ?panic ?refused ?unreachable ?unavailable ?timeout ?segfault ?corrupt ?crash ?fatal ?exited ?\"authentication failure\" ?\"Connection refused\" ?\"Control process exited\" ?\"Failed with result\" ?\"test failed\""

  metric_transformation {
    name      = "errorcount"
    namespace = "syslog"
    value     = "1"
  }

  lifecycle {
    ignore_changes = [metric_transformation]
  }
}