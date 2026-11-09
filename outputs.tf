output "s3_bucket_name" {
  description = "Name of the local S3 bucket"
  value       = aws_s3_bucket.sample_bucket.bucket
}

output "dynamodb_table_name" {
  description = "Name of the local DynamoDB table"
  value       = aws_dynamodb_table.sample_table.name
}

output "lambda_function_name" {
  description = "Name of the local Python Lambda function"
  value       = aws_lambda_function.sample_lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the local Python Lambda function"
  value       = aws_lambda_function.sample_lambda.arn
}
