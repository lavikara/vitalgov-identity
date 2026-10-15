output "secret_arns" {
  description = "Map of secret key → ARN, injected into the ECS task definitions."
  value       = { for k, s in aws_secretsmanager_secret.secret : k => s.arn }
}
