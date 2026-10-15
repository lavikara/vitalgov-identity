output "bucket_name" {
  description = "Name of the bucket receiving CloudTrail and ALB access logs."
  value       = aws_s3_bucket.logs.id
}
