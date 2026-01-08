# ----------------------------
# IAM role for Lambda
# ----------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Basic Lambda logging to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SNS publish permission
# Requires aws_sns_topic.alerts to exist (defined in sns.tf).
resource "aws_iam_role_policy" "lambda_sns_publish" {
  name = "${var.name_prefix}-lambda-sns-publish"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sns:Publish"],
      Resource = aws_sns_topic.alerts.arn
    }]
  })
}





resource "aws_iam_role_policy" "lambda_bedrock_invoke" {
  name = "${var.name_prefix}-lambda-bedrock-invoke"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "bedrock:InvokeModel",
        "bedrock:Converse"
      ],
      Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/*"
    }]
  })
}