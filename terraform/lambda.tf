variable "src" {
  type = string
  default = "../src/"
}

# Zip file used for report lambda

# Inspiration from https://callaway.dev/deploy-python-lambdas-with-terraform/
# https://repost.aws/knowledge-center/lambda-python-package-compatible
# Probably want to put the openpyxl bits in a layer, and tie that to the report Lambda?

resource "null_resource" "install_report_dependencies" {
  provisioner "local-exec" {
    command = "rm -fr ${var.src}report/packaging; pip install -r ${var.src}report/requirements.txt -t ${var.src}report/packaging/"
  }
  triggers = {
    dependencies_versions = filemd5("${var.src}report/requirements.txt")
    source_versions = filemd5("${var.src}report/process_report.py")
  }
}

resource "null_resource" "install_report_source" {
  depends_on = [
    null_resource.install_report_dependencies
  ]
  provisioner "local-exec" {
    command = "cp -p ${var.src}report/process_report.py ${var.src}report/packaging/"
  }
  triggers = {
    source_versions = filemd5("${var.src}report/process_report.py")
  }
}

# resource "random_uuid" "report_hash" {
#   keepers = {
#     for filename in setunion(
#       fileset("${var.src}report", "process_report.py"),
#       fileset("${var.src}report", "requirements.txt")):
#     filename => filemd5("${var.src}report/${filename}")
#   }
# }

data "archive_file" "report" {
  depends_on = [
    null_resource.install_report_dependencies,
    null_resource.install_report_source
  ]
  excludes = [
    "__pycache__",
    "venv"
  ]
  source_dir = "${var.src}report/packaging"
  # output_path = "${random_uuid.report_hash.result}.zip"
  output_path = "lambda-report.zip"
  type = "zip"
}

# Role attached to report lambda

data "aws_iam_policy_document" "run_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "report" {
  name = "report_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.run_lambda.json
}

# The actual lambda function, with the entry point (handler) and runtime

resource "aws_lambda_function" "report" {
  function_name = "report"
  role = aws_iam_role.report.arn
  filename = data.archive_file.report.output_path
  source_code_hash = filebase64sha256(data.archive_file.report.output_path)
  handler = "process_report.report_handler"
  runtime = "python3.8"
  publish = true
  timeout = 10

  environment {
    variables = {
      S3_NAME  = var.bucket_name
      SQS_URL  = aws_sqs_queue.posts.url
      ESM_UUID = aws_lambda_event_source_mapping.post_trigger.uuid
    }
  }
}

# A policy to allow logging to Cloudwatch

data "aws_iam_policy_document" "cloudwatch_logging" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_iam_policy" "warn_logging_policy" {
  name = "warn_logging_policy"
  path = "/"
  policy = data.aws_iam_policy_document.cloudwatch_logging.json
}

# A policy to allow sending to the SQS queue

data "aws_iam_policy_document" "warn_sqs_sending" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [
      aws_sqs_queue.posts.arn
    ]
  }
}

resource "aws_iam_policy" "warn_sqs_sending" {
  name = "warn_sqs_sending_policy"
  path = "/"
  policy = data.aws_iam_policy_document.warn_sqs_sending.json
}

# A policy to allow receiving from the SQS queue

data "aws_iam_policy_document" "warn_sqs_receiving" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      aws_sqs_queue.posts.arn
    ]
  }
}

resource "aws_iam_policy" "warn_sqs_receiving" {
  name = "warn_sqs_receiving_policy"
  path = "/"
  policy = data.aws_iam_policy_document.warn_sqs_receiving.json
}

# A policy to allow reading/listing/writing of our S3 bucket

data "aws_iam_policy_document" "warn_s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "*"
    ]
  }
}
# "*" worked, but I'd prefer something more specific, like this (which didn't):
#
# aws_s3_bucket.warn_bucket.arn,
# "${aws_s3_bucket.warn_bucket.arn}:*"

resource "aws_iam_policy" "warn_s3_access" {
  name = "warn_s3_access_policy"
  path = "/"
  policy = data.aws_iam_policy_document.warn_s3_access.json
}

# A policy to allow reading (all) SSM parameters

data "aws_iam_policy_document" "warn_ssm_reading" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter"
    ]
    resources = [
      aws_ssm_parameter.api_server.arn,
      aws_ssm_parameter.api_token.arn,
    ]
  }
}

resource "aws_iam_policy" "warn_ssm_reading" {
  name = "warn_ssm_reading_policy"
  path = "/"
  policy = data.aws_iam_policy_document.warn_ssm_reading.json
}

# A policy to allow getting/updating event source mapping
data "aws_iam_policy_document" "warn_esm_reading" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:GetEventSourceMapping",
      "lambda:UpdateEventSourceMapping"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "warn_esm_reading" {
  name = "warn_esm_reading_policy"
  path = "/"
  policy = data.aws_iam_policy_document.warn_esm_reading.json
}

# Other permissions (like writing to SQS and reading/writing to S3 to follow later)

# Policy

# Zip file used for posts lambda

data "archive_file" "post" {
  type = "zip"
  source_file = "${var.src}posts/process_posts.py"
  output_path = "lambda-post.zip"
}

# Role attached to report lambda

resource "aws_iam_role" "post" {
  name = "post_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.run_lambda.json
}

# The actual lambda function, with the entry point (handler) and runtime

resource "aws_lambda_function" "post" {
  filename = data.archive_file.post.output_path
  function_name = "post"
  role = aws_iam_role.post.arn
  handler = "process_posts.posts_handler"
  runtime = "python3.8"
  source_code_hash = filebase64sha256(data.archive_file.post.output_path)
  publish = true
  timeout = 10
}

# Attach cloudwatch logging permissions and S3 access permissions to
# both lambda roles

resource "aws_iam_policy_attachment" "warn_both_attachment" {
  for_each = {
    "logging"     = aws_iam_policy.warn_logging_policy.arn
    "s3-access"   = aws_iam_policy.warn_s3_access.arn,
    "esm-reading" = aws_iam_policy.warn_esm_reading.arn,
    "sqs-sending" = aws_iam_policy.warn_sqs_sending.arn
  }
  name = "warn-${each.key}-attachment"
  roles = [
    aws_iam_role.report.name,
    aws_iam_role.post.name
  ]
  policy_arn = each.value
}

# Attach SQS sending permissions to the report lambda role

resource "aws_iam_policy_attachment" "warn_report_attachment" {
  for_each = {
  }
  name = "warn-report-${each.key}-attachment"
  roles = [
    aws_iam_role.report.name
  ]
  policy_arn = each.value
}

# Attach SQS receiving permissions and SSM parameter permissions to
# the post lambda role

resource "aws_iam_policy_attachment" "warn_post_attachment" {
  for_each = {
    "sqs-receiving" = aws_iam_policy.warn_sqs_receiving.arn
    "ssm-reading"   = aws_iam_policy.warn_ssm_reading.arn
  }
  name = "warn-post-${each.key}-attachment"
  roles = [
    aws_iam_role.post.name
  ]
  policy_arn = each.value
}

# Set the "post" lambda up to be triggered by the SQS queue

resource "aws_lambda_event_source_mapping" "post_trigger" {
  event_source_arn = aws_sqs_queue.posts.arn
  function_name = aws_lambda_function.post.arn
  # Start disabled, let the report Lambda enable it, and the post
  # lambda disable it again when it's finished with a thread.
  enabled = false
}

# Set retention on the future cloudwatch log groups before it's too late

resource "aws_cloudwatch_log_group" "loggroups" {
  for_each = toset([
    "/aws/lambda/${aws_lambda_function.report.function_name}",
    "/aws/lambda/${aws_lambda_function.post.function_name}"
  ])
  name = each.key
  retention_in_days = 7
}
