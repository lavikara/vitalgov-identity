output "bucket_name" {
  description = "Name of the S3 state bucket."
  value       = aws_s3_bucket.tfstate.id
}

output "bucket_arn" {
  description = "ARN of the S3 state bucket."
  value       = aws_s3_bucket.tfstate.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB lock table."
  value       = aws_dynamodb_table.tflock.name
}
