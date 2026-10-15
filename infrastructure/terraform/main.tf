locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Precedence: provided ARN > domain cert > self-signed (capstone HTTPS without a domain).
  use_domain_cert = var.certificate_arn == null && var.domain_name != null
  use_self_signed = var.certificate_arn == null && var.domain_name == null

  certificate_arn = (
    var.certificate_arn != null ? var.certificate_arn :
    local.use_domain_cert ? module.acm[0].certificate_arn :
    aws_acm_certificate.self_signed[0].arn
  )
}

module "networking" {
  source = "./Networking"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  data_subnet_cidrs   = var.data_subnet_cidrs
  pki_subnet_cidrs    = var.pki_subnet_cidrs
  log_retention_days  = var.log_retention_days
  common_tags         = local.common_tags
}

module "security_groups" {
  source = "./SecurityGroups"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  vpc_cidr           = var.vpc_cidr
  alb_target_port    = var.container_port
  gateway_admin_port = var.gateway_admin_port
  api_port           = var.container_port
  keycloak_port      = var.keycloak_port
  ca_port            = var.ca_port
  common_tags        = local.common_tags
}

module "vpc_endpoints" {
  source = "./VpcEndpoints"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_id                      = module.networking.vpc_id
  app_subnet_ids              = module.networking.app_subnet_ids
  app_route_table_ids         = module.networking.app_route_table_ids
  data_route_table_ids        = module.networking.data_route_table_ids
  pki_route_table_ids         = module.networking.pki_route_table_ids
  endpoints_security_group_id = module.security_groups.endpoints_security_group_id
  common_tags                 = local.common_tags
}

module "ecr" {
  source = "./Ecr"

  project_name        = var.project_name
  environment         = var.environment
  ecr_repository_name = var.ecr_repository_name
  common_tags         = local.common_tags
}

module "alb" {
  source = "./Alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  container_port    = var.container_port
  enable_https      = true # a certificate is always available (provided, domain, or self-signed)
  certificate_arn   = local.certificate_arn

  alb_security_group_id      = module.security_groups.alb_security_group_id
  access_log_bucket          = module.logs.bucket_name
  enable_deletion_protection = var.enable_deletion_protection
  common_tags                = local.common_tags

  depends_on = [module.logs]
}

module "secrets_manager" {
  source = "./SecretsManager"

  project_name = var.project_name
  environment  = var.environment
  # db_hostname (no port): drivers resolve DB_HOST as a bare hostname.
  db_host                 = module.rds.db_hostname
  db_name                 = var.db_name
  db_user                 = var.db_username
  db_password             = var.db_password
  jwt_secret              = var.jwt_secret
  keycloak_admin_password = var.keycloak_admin_password
  common_tags             = local.common_tags
}

# One cluster, two services (API + Keycloak); tasks run private with no public IP (ADR-004/ADR-010).
module "ecs" {
  source = "./Ecs"

  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  app_subnet_ids         = module.networking.app_subnet_ids
  target_group_arn       = module.alb.target_group_arn
  enable_execute_command = var.enable_execute_command
  log_retention_days     = var.log_retention_days

  services = {
    (var.ecs_service_name) = {
      container_name    = "vitalgov-api"
      container_image   = var.container_image
      container_port    = var.container_port
      cpu               = var.api_cpu
      memory            = var.api_memory
      desired_count     = var.desired_count
      health_check_path = "/health"
      security_group_id = module.security_groups.api_security_group_id
      environment = {
        AWS_REGION  = var.aws_region
        ENVIRONMENT = var.environment
      }
      secrets = {
        DB_HOST     = module.secrets_manager.secret_arns["db-host"]
        DB_NAME     = module.secrets_manager.secret_arns["db-name"]
        DB_USER     = module.secrets_manager.secret_arns["db-user"]
        DB_PASSWORD = module.secrets_manager.secret_arns["db-password"]
        JWT_SECRET  = module.secrets_manager.secret_arns["jwt-secret"]
      }
      attach_to_target_group = true
    }

    "vitalgov-keycloak" = {
      container_name    = "keycloak"
      container_image   = var.keycloak_image
      container_port    = var.keycloak_port
      cpu               = var.keycloak_cpu
      memory            = var.keycloak_memory
      desired_count     = var.desired_count
      health_check_path = "/realms/master"
      # Keycloak images ship no wget; bash /dev/tcp checks the socket.
      health_check_cmd  = "exec 3<>/dev/tcp/localhost/8080 && printf 'GET /realms/master HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n' >&3 && grep -q '200 OK' <&3"
      security_group_id = module.security_groups.keycloak_security_group_id
      environment = {
        AWS_REGION     = var.aws_region
        KC_DB          = "postgres"
        KC_DB_URL_HOST = module.rds.db_hostname
        # The database RDS actually creates (var.db_name); a literal "keycloak" DB never exists and crashes Keycloak.
        KC_DB_URL_DATABASE          = var.db_name
        KC_DB_URL_SCHEMA            = "keycloak"
        KC_DB_USERNAME              = var.db_username
        KC_BOOTSTRAP_ADMIN_USERNAME = var.keycloak_admin_username
        KC_HOSTNAME_STRICT          = "false"
      }
      secrets = {
        KC_DB_PASSWORD              = module.secrets_manager.secret_arns["db-password"]
        KC_BOOTSTRAP_ADMIN_PASSWORD = module.secrets_manager.secret_arns["keycloak-admin-password"]
      }
      attach_to_target_group = false
    }
  }

  common_tags = local.common_tags
}

module "rds" {
  source = "./Database"

  project_name            = var.project_name
  environment             = var.environment
  data_subnet_ids         = module.networking.data_subnet_ids
  rds_security_group_id   = module.security_groups.rds_security_group_id
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  monitoring_interval     = var.rds_monitoring_interval
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.enable_deletion_protection
  common_tags             = local.common_tags
}

module "s3" {
  source = "./S3"

  project_name   = var.project_name
  environment    = var.environment
  bucket_purpose = "realm-backups"
  common_tags    = local.common_tags
}

module "logs" {
  source = "./logs"

  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags
}

module "observability" {
  source = "./Observability"

  project_name        = var.project_name
  environment         = var.environment
  alb_id              = module.alb.alb_id
  target_group_id     = module.alb.target_group_id
  ecs_cluster_name    = module.ecs.ecs_cluster_name
  ecs_service_name    = var.ecs_service_name
  ecs_desired_count   = var.desired_count
  db_instance_id      = module.rds.db_instance_id
  budget_limit_usd    = var.budget_limit_usd
  budget_alert_emails = var.budget_alert_emails
  log_bucket_name     = module.logs.bucket_name
  deploy_role_arn     = module.iam.github_actions_role_arn
  common_tags         = local.common_tags

  # Trail validates the bucket policy at creation; wait for the whole module.
  depends_on = [module.logs]
}

module "ops" {
  source = "./Ops"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  app_subnet_ids        = module.networking.app_subnet_ids
  ops_security_group_id = module.security_groups.ops_security_group_id
  tailscale_auth_key    = var.tailscale_auth_key
  wazuh_manager_ip      = var.wazuh_manager_ip
  common_tags           = local.common_tags
}

# CMK always; host gated by create_ca_host until the I-007 decision (Ismail).
module "pki" {
  source = "./Pki"

  project_name         = var.project_name
  environment          = var.environment
  pki_subnet_ids       = module.networking.pki_subnet_ids
  ca_security_group_id = module.security_groups.ca_security_group_id
  create_ca_host       = var.create_ca_host
  deploy_role_arn      = module.iam.github_actions_role_arn
  common_tags          = local.common_tags
}

module "iam" {
  source = "./iam"

  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  github_org          = var.github_org
  github_repo         = var.github_repo
  github_org_id       = var.github_org_id
  github_repo_id      = var.github_repo_id
  ecr_repository_name = var.ecr_repository_name
}

module "state" {
  source = "./state"

  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags
}

module "acm" {
  source = "./Acm"
  count  = local.use_domain_cert ? 1 : 0

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name
  common_tags  = local.common_tags
}

# Self-signed cert imported to ACM so the ALB serves HTTPS :443 until the free DNS domain is validated (ADR-004).
resource "tls_private_key" "self_signed" {
  count = local.use_self_signed ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed" {
  count = local.use_self_signed ? 1 : 0

  private_key_pem = tls_private_key.self_signed[0].private_key_pem

  subject {
    common_name  = "${var.project_name}.local"
    organization = var.project_name
  }

  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "self_signed" {
  count = local.use_self_signed ? 1 : 0

  private_key      = tls_private_key.self_signed[0].private_key_pem
  certificate_body = tls_self_signed_cert.self_signed[0].cert_pem

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-self-signed"
  })
}
