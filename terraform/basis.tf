######################################################################
# S3 Bucket
######################################################################

resource "aws_s3_bucket" "warn_bucket" {
  bucket = var.bucket_name

  tags = {
    Name = "WARN"
  }
}

resource "aws_s3_bucket_acl" "warn_bucket" {
  bucket = aws_s3_bucket.warn_bucket.id

  acl = "private"
  depends_on = [aws_s3_bucket_ownership_controls.warn_bucket]
}

# https://stackoverflow.com/questions/76049290/error-accesscontrollistnotsupported-when-trying-to-create-a-bucket-acl-in-aws
# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
#
# May also be fixed by upgrading to a newer Terraform version (3.10.1?)
resource "aws_s3_bucket_ownership_controls" "warn_bucket" {
  bucket = aws_s3_bucket.warn_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

######################################################################
# SSM Parameter
######################################################################

resource "aws_ssm_parameter" "api_server" {
  name = "/WARN/api_server"
  type = "String"
  value = var.api_server
}

resource "aws_ssm_parameter" "api_token" {
  name = "/WARN/api_token"
  type = "SecureString"
  value = var.api_token
}

######################################################################
# SQS queue along with the DLQ
######################################################################

resource "aws_sqs_queue" "posts-dlq" {
  name = "posts-dlq"
  tags = {
    Name = "WARN-DLQ"
  }
}

resource "aws_sqs_queue" "posts" {
  name = "posts"

  # When using a FIFO queue, you can't specify DelaySeconds when sending a
  # message, which is what exactly what I wanted to do. Oh well.
  #
  # name = "posts.fifo"
  # fifo_queue = true

  # This timeout needs to be at least as long as the timeout of the Lambda
  # hooked up to this queue
  visibility_timeout_seconds = 10
  # content_based_deduplication = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.posts-dlq.arn
    maxReceiveCount     = 1
  })

  tags = {
    Name = "WARN"
  }
}

resource "aws_sqs_queue_redrive_allow_policy" "posts-dlq" {
  queue_url = aws_sqs_queue.posts-dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.posts.arn]
  })
}

######################################################################
# SNS topic for sending CW alarms
######################################################################

resource "aws_sns_topic" "alarms" {
  name = "alarms"
}

# Set up an (email) SNS subscription

resource "aws_sns_topic_subscription" "alarms-email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol = "email"
  endpoint = "chaos-stats@spam.is-here.com"
}
