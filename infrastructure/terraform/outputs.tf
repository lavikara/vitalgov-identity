output "vpc_id" {
  description = "ID of the VitalGov VPC."
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB + NAT placement)."
  value       = module.networking.public_subnet_ids
}

output "app_subnet_ids" {
  description = "Private application subnet IDs (ECS, ops host)."
  value       = module.networking.app_subnet_ids
}

output "data_subnet_ids" {
  description = "Private data subnet IDs (RDS)."
  value       = module.networking.data_subnet_ids
}

output "pki_subnet_ids" {
  description = "Restricted PKI-tier subnet IDs."
  value       = module.networking.pki_subnet_ids
}

output "alb_dns_name" {
  description = "Public entry point of the platform."
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster running the API and Keycloak."
  value       = module.ecs.ecs_cluster_name
}

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint."
  value       = module.rds.db_endpoint
}

output "secret_arns" {
  description = "Secrets Manager ARNs consumed by the ECS task roles."
  value       = module.secrets_manager.secret_arns
}

output "realm_backup_bucket" {
  description = "S3 bucket receiving daily Keycloak realm exports."
  value       = module.s3.bucket_name
}

output "log_bucket_name" {
  description = "S3 bucket receiving CloudTrail and ALB access logs."
  value       = module.logs.bucket_name
}

output "state_bucket_name" {
  description = "Terraform state bucket."
  value       = module.state.bucket_name
}

output "github_actions_role_arn" {
  description = "OIDC deploy role assumed by GitHub Actions."
  value       = module.iam.github_actions_role_arn
}

output "ops_instance_ids" {
  description = "Ops-tier EC2 instance (Tailscale connector + Wazuh log-forwarder)."
  value       = module.ops.instance_ids
}

output "ca_kms_key_arn" {
  description = "KMS CMK protecting the issuing CA key material."
  value       = module.pki.ca_kms_key_arn
}

output "ca_host_id" {
  description = "CA host in the PKI tier (null until create_ca_host = true)."
  value       = module.pki.ca_host_id
}
