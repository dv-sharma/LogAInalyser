resource "aws_cloudwatch_event_rule" "syslogerrors" {
  name                = "syslogerrors"
  schedule_expression = "rate(2 minutes)"
  state               = "DISABLED"
}


resource "aws_cloudwatch_event_target" "syslogerrors_lambda" {
  rule      = aws_cloudwatch_event_rule.syslogerrors.name
  target_id = "000esd0wdg8hhwmjf8rh"
  arn       = aws_lambda_function.syslogerrors.arn
}

resource "aws_lambda_permission" "allow_eventbridge_syslogerrors" {
  statement_id  = "lambda-945ff033-57ff-424e-8fbd-777da2e8e467"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.syslogerrors.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.syslogerrors.arn
}