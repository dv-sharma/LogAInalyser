resource "aws_iam_policy" "rstudiodatapolicy" {
  name   = "rstudiodatapolicy"
  path   = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::rstudiodataset/forestfires.csv"
      }
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}