provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

variable "lambda_function_name" {
  default = "s3_file_line_counter"
}

resource "aws_s3_bucket" "lambda-bucket" {
  bucket        = "lambda-bucket-${uuid()}"
  force_destroy = true
}

resource "aws_s3_object" "s3_input_folder" {
  bucket = aws_s3_bucket.lambda-bucket.id
  key    = "input/"
}

resource "aws_s3_object" "s3_output_folder" {
  bucket = aws_s3_bucket.lambda-bucket.id
  key    = "output/"
}

data "aws_iam_policy_document" "iam_assume_role_lambda_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "iam_assume_role_lambda" {
  name = "iam_assume_role_lambda"

  assume_role_policy = data.aws_iam_policy_document.iam_assume_role_lambda_document.json
}

data "aws_iam_policy_document" "iam_s3_lambda_document" {
  statement {
    sid     = "Stmt1650361188691"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    effect    = "Allow"
    resources = [
      aws_s3_bucket.lambda-bucket.arn,
      "${aws_s3_bucket.lambda-bucket.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "iam_s3_lambda" {
  name       = "iam_s3_lambda"
  policy     = data.aws_iam_policy_document.iam_s3_lambda_document.json
  depends_on = [aws_s3_bucket.lambda-bucket]
}

data "aws_iam_policy_document" "iam_lambda_logging_document" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = data.aws_iam_policy_document.iam_lambda_logging_document.json
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
}

resource "aws_lambda_permission" "bucket_notification" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_file_counter_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.lambda-bucket.arn
}

resource "aws_s3_bucket_notification" "s3_bucket_notification" {
  bucket = aws_s3_bucket.lambda-bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_file_counter_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "input/"
    filter_suffix       = ".txt"
  }

  depends_on = [aws_lambda_permission.bucket_notification]
}

resource "aws_lambda_function" "s3_file_counter_lambda" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.iam_assume_role_lambda.arn
  handler          = "AWSCountS3FileLines::AWSCountS3FileLines.Function::FunctionHandler"
  runtime          = "dotnetcore3.1"
  filename         = "${path.module}/../bin/Release/netcoreapp3.1/AWSCountS3FileLines.zip"
  source_code_hash = filebase64sha256("${path.module}/../bin/Release/netcoreapp3.1/AWSCountS3FileLines.zip")
  timeout          = 30

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs_attachment,
    aws_iam_role_policy_attachment.lambda_s3_attachment,
    aws_cloudwatch_log_group.lambda_log_group
  ]
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attachment" {
  role       = aws_iam_role.iam_assume_role_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  role       = aws_iam_role.iam_assume_role_lambda.name
  policy_arn = aws_iam_policy.iam_s3_lambda.arn
}

resource "aws_default_vpc" "default" {}
