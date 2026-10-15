output "github_actions_role_arn" {
  description = "ARN of the OIDC deploy role for GitHub Actions."
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Name of the OIDC deploy role."
  value       = aws_iam_role.github_actions.name
}
