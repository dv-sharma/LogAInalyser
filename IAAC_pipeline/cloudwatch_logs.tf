resource "aws_cloudwatch_log_group" "syslog" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days

  tags = { Name = "${var.name_prefix}-loggroup" }
}

# ----------------------------
# Allow CloudWatch Logs to invoke Lambda
# ----------------------------
resource "aws_lambda_permission" "allow_cwlogs_invoke" {
  statement_id  = "AllowCloudWatchLogsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.subscription_receiver.function_name
  principal     = "logs.amazonaws.com"

  # Allow invocations from this log group
  source_arn = "${aws_cloudwatch_log_group.syslog.arn}:*"
}

# ----------------------------
# CloudWatch Logs subscription filter (syslog -> lambda)
# ----------------------------
resource "aws_cloudwatch_log_subscription_filter" "syslog_to_lambda" {
  name           = "${var.name_prefix}-syslog-to-lambda"
  log_group_name = aws_cloudwatch_log_group.syslog.name

  # Filter to reduce noise: only likely error signals.
  # CloudWatch Logs filter patterns are NOT regex; these are term filters.
 filter_pattern = "?fail ?failed ?error ?denied ?unauthorized ?invalid ?panic ?refused ?unreachable ?unavailable ?timeout ?segfault ?corrupt ?crash ?fatal ?exited ?\"authentication failure\" ?\"Connection refused\" ?\"Control process exited\" ?\"Failed with result\" ?\"test failed\""


  destination_arn = aws_lambda_function.subscription_receiver.arn

  depends_on = [aws_lambda_permission.allow_cwlogs_invoke]
}
