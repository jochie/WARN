# The actual EventBridge rule:

resource "aws_cloudwatch_event_rule" "report_event_rule" {
  name = "report_event_rule"
  description = "Event for report lambda"
  schedule_expression = "rate(2 hours)"
}

# What the rule targets:

resource "aws_cloudwatch_event_target" "report_target" {
  rule = aws_cloudwatch_event_rule.report_event_rule.name
  target_id = "report_target"
  arn = aws_lambda_function.report.arn
}

# Grant permission to invoke the lambda function:

resource "aws_lambda_permission" "report_event_permissions" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.report_event_rule.arn
}
