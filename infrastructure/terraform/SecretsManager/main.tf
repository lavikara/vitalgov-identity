locals {
  common_tags = merge(
    var.common_tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "Secrets"
    }
  )
}

# AWS-managed key; a CMK adds audit/rotation at ~$1/mo, only the brief-mandated CA key uses one.
locals {
  secrets = {
    "db-host"                 = var.db_host
    "db-name"                 = var.db_name
    "db-user"                 = var.db_user
    "db-password"             = var.db_password
    "jwt-secret"              = var.jwt_secret
    "keycloak-admin-password" = var.keycloak_admin_password
  }
}

resource "aws_secretsmanager_secret" "secret" {
  for_each = local.secrets

  name = "/${var.project_name}/${var.environment}/${each.key}"

  kms_key_id = "alias/aws/secretsmanager"

  tags = merge(
    local.common_tags,
    {
      Name = "/${var.project_name}/${var.environment}/${each.key}"
    }
  )
}

resource "aws_secretsmanager_secret_version" "secret" {
  for_each = local.secrets

  secret_id     = aws_secretsmanager_secret.secret[each.key].id
  secret_string = each.value
}
