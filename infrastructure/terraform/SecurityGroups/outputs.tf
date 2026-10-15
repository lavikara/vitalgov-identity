output "alb_security_group_id" {
  description = "Security group ID of the ALB."
  value       = aws_security_group.alb.id
}

output "gateway_security_group_id" {
  description = "Security group ID of the gateway tier."
  value       = aws_security_group.gateway.id
}

output "keycloak_security_group_id" {
  description = "Security group ID of the Keycloak tier."
  value       = aws_security_group.keycloak.id
}

output "api_security_group_id" {
  description = "Security group ID of the API tier."
  value       = aws_security_group.api.id
}

output "rds_security_group_id" {
  description = "Security group ID of the RDS tier."
  value       = aws_security_group.rds.id
}

output "ca_security_group_id" {
  description = "Security group ID of the CA tier."
  value       = aws_security_group.ca.id
}

output "ops_security_group_id" {
  description = "Security group ID of the ops tier."
  value       = aws_security_group.ops.id
}

output "endpoints_security_group_id" {
  description = "Security group ID of the VPC interface endpoints."
  value       = aws_security_group.endpoints.id
}
