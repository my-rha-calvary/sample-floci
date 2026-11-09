# ---------------------------------------------------------------------------
# 1. S3 Bucket
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "sample_bucket" {
  bucket        = "floci-sample-bucket"
  force_destroy = true
}

# ---------------------------------------------------------------------------
# 2. DynamoDB Table
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "sample_table" {
  name         = "FlociSampleItems"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ---------------------------------------------------------------------------
# 3. IAM Execution Role for Lambda
# ---------------------------------------------------------------------------
resource "aws_iam_role" "lambda_exec_role" {
  name = "floci_lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "floci_lambda_s3_dynamo_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.sample_bucket.arn,
          "${aws_s3_bucket.sample_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.sample_table.arn
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# 4. Package & Deploy Python Lambda Function
# ---------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/lambda_payload.zip"
}

resource "aws_lambda_function" "sample_lambda" {
  function_name    = "floci-sample-python-fn"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.sample_bucket.bucket
      TABLE_NAME  = aws_dynamodb_table.sample_table.name
    }
  }
}
