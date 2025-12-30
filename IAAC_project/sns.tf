resource "aws_sns_topic" "syslogerrors_notify" {
  name = "syslogerrors"
}

resource "aws_sns_topic_subscription" "syslogerrors_email" {
  topic_arn = aws_sns_topic.syslogerrors_notify.arn
  protocol  = "email"
  endpoint  = var.sns_notification_email

  confirmation_timeout_in_minutes = 1
  endpoint_auto_confirms          = false

  lifecycle {
    prevent_destroy = true
  }
}
