data "archive_file" "syslogerrors" {
  type        = "zip"
  source_file = "${path.module}/code/lambda_function.py"
  output_path = "${path.module}/build/syslogerrors.zip"
}

resource "aws_lambda_function" "syslogerrors" {
  function_name = "syslogerrors"
  role          = "arn:aws:iam::684272599297:role/service-role/syslogerrors-role-bixsl5e4"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.13"
  timeout       = 61
  memory_size   = 1024

  filename         = data.archive_file.syslogerrors.output_path
  source_code_hash = data.archive_file.syslogerrors.output_base64sha256

  environment {
    variables = {
      REGION           = "us-east-1"
      LOG_GROUP        = aws_cloudwatch_log_group.syslog.name
      SNS_TOPIC_ARN    = aws_sns_topic.syslogerrors_notify.arn
      LOOKBACK_MINUTES = "5"
      MAX_EVENTS       = "5000"
      # FILTER_PATTERN = "..."  # optional
      # MODEL_ID       = "..."  # optional
    }
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}
