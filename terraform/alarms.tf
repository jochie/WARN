# Trigger an alarm for when there is content sitting in the posts-dlq

resource "aws_cloudwatch_metric_alarm" "dlq" {
  alarm_name = "WARN-DLQ"
  alarm_description = "Alert if something is dropped in the DLQ"

  namespace = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  statistic = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold = 0
  period = 300
  evaluation_periods = 1
  actions_enabled = "true"
  treat_missing_data = "notBreaching"
  dimensions = {
    QueueName = aws_sqs_queue.posts-dlq.name
  }
  alarm_actions = [ aws_sns_topic.alarms.arn ]
}
