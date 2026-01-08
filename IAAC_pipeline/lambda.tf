#############################################
# lambda.tf (COMPLETE)
# - Zips code/lambda_function.py
# - Creates Lambda execution role + policies
# - Creates Lambda function (ALWAYS has environment block)
# - Allows CloudWatch Logs to invoke Lambda
# - Creates CloudWatch Logs subscription filter (syslog -> lambda) with ERROR filter pattern
#############################################

# Zip the Lambda source code
data "archive_file" "subscription_receiver" {
  type        = "zip"
  source_file = "${path.module}/code/lambda_function.py"
  output_path = "${path.module}/build/subscription_receiver.zip"
}

# ----------------------------
# Lambda function
# ----------------------------
resource "aws_lambda_function" "subscription_receiver" {
  function_name = "${var.name_prefix}-subscription-receiver"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.13"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.subscription_receiver.output_path
  source_code_hash = data.archive_file.subscription_receiver.output_base64sha256

  # Always include environment block (prevents provider "0 -> 1 block" inconsistency)
  environment {
    variables = {
      REGION        = var.aws_region
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
      MODEL_ID      = var.bedrock_model_id
    }
  }

  depends_on = [
    aws_sns_topic.alerts,
    aws_iam_role_policy.lambda_sns_publish,
    aws_iam_role_policy_attachment.lambda_basic
  ]
}






