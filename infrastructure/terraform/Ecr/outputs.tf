output "repository_url" {
  description = "URL of the ECR repository."
  value       = aws_ecr_repository.api.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository."
  value       = aws_ecr_repository.api.arn
}
