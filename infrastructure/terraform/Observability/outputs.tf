output "sns_topic_arn" {
  description = "ARN of the alarm SNS topic."
  value       = aws_sns_topic.alarms.arn
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail trail."
  value       = aws_cloudtrail.project.name
}

output "trail_kms_key_arn" {
  description = "ARN of the CMK encrypting CloudTrail logs."
  value       = aws_kms_key.trail.arn
}
