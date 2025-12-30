resource "aws_iam_role" "rstudio" {
  name = "rstudio"
  description = "Allows EC2 instances to call AWS services on your behalf."
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_instance_profile" "rstudio" {
  name = "rstudio"
  role = aws_iam_role.rstudio.name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy" "rstudio_bedrocklogs" {
  name = "Bedrocklogs"
  role = aws_iam_role.rstudio.name

  # This matches what your plan output showed
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = ["*"]
      }
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}


resource "aws_iam_role_policy_attachment" "rstudio_rstudiodatapolicy" {
  role       = aws_iam_role.rstudio.name
  policy_arn = "arn:aws:iam::684272599297:policy/rstudiodatapolicy"
}

resource "aws_iam_role_policy_attachment" "rstudio_cloudwatch_agent" {
  role       = aws_iam_role.rstudio.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "rstudio_ec2_readonly" {
  role       = aws_iam_role.rstudio.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "rstudio_bedrock_full" {
  role       = aws_iam_role.rstudio.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}