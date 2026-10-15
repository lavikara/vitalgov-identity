# One module keeps the §7.2 matrix reviewable; all rules standalone (inline mixing makes the provider revoke unmanaged ones).

locals {
  common_tags = merge(
    var.common_tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "SecurityGroups"
    }
  )
}

# Security groups

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "ALB: inbound HTTPS from clinic users, outbound to the API tier."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
    Tier = "LoadBalancer"
  })
}

resource "aws_security_group" "gateway" {
  name        = "${var.project_name}-${var.environment}-gateway-sg"
  description = "API gateway tier: receives traffic only from the ALB (deployed after the gateway decision)."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-gateway-sg"
    Tier = "Gateway"
  })
}

resource "aws_security_group" "keycloak" {
  name        = "${var.project_name}-${var.environment}-keycloak-sg"
  description = "Keycloak IdP: identity endpoints for the API, LDAPS/SAML egress for federation."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-keycloak-sg"
    Tier = "Identity"
  })
}

resource "aws_security_group" "api" {
  name        = "${var.project_name}-${var.environment}-api-sg"
  description = "Application API tier."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-api-sg"
    Tier = "Application"
  })
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "RDS PostgreSQL: ingress only from API and Keycloak."
  vpc_id      = var.vpc_id

  # No egress (RDS initiates nothing); no inline egress block: an empty-CIDR rule would keep the plan dirty.

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-sg"
    Tier = "Database"
  })
}

resource "aws_security_group" "ca" {
  name        = "${var.project_name}-${var.environment}-ca-sg"
  description = "PKI/CA tier: CA/OCSP port from the gateway; admin via SSM only, no inbound SSH."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ca-sg"
    Tier = "PKI"
  })
}

resource "aws_security_group" "ops" {
  name        = "${var.project_name}-${var.environment}-ops-sg"
  description = "Ops tier (Tailscale connector + Wazuh log-forwarder on one host): no inbound rules; initiates everything."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ops-sg"
    Tier = "Ops"
  })
}

resource "aws_security_group" "endpoints" {
  name        = "${var.project_name}-${var.environment}-endpoints-sg"
  description = "VPC interface endpoints: HTTPS from the tiers that consume AWS services."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-endpoints-sg"
    Tier = "Endpoints"
  })
}

# F1/F2 - ALB ingress and forwarding

resource "aws_security_group_rule" "alb_ingress_https" {
  description       = "F1: clinic user HTTPS - the only internet-facing listener in the design"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = var.ingress_cidr_blocks
}

resource "aws_security_group_rule" "alb_ingress_http_redirect" {
  description       = "HTTP redirect to HTTPS (listener returns 301; no content served)"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = var.ingress_cidr_blocks
}

# Wave 1: ALB to API directly; retarget to the gateway SG (F2) when the gateway tier deploys.
resource "aws_security_group_rule" "alb_egress_to_api" {
  description              = "F2 (wave 1 shape): forward to API targets only"
  type                     = "egress"
  from_port                = var.alb_target_port
  to_port                  = var.alb_target_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.api.id
}

resource "aws_security_group_rule" "alb_dns_udp" {
  description       = "DNS to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "alb_dns_tcp" {
  description       = "DNS over TCP to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = [var.vpc_cidr]
}

# Gateway tier rules exist now so the matrix is complete; the service deploys after the API-gateway decision.

resource "aws_security_group_rule" "gateway_ingress_target" {
  description              = "F2: client traffic exclusively through the ALB"
  type                     = "ingress"
  from_port                = var.alb_target_port
  to_port                  = var.alb_target_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.gateway.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "gateway_ingress_admin_from_ops" {
  description              = "Gateway configuration/API administration from the ops tier; no public path"
  type                     = "ingress"
  from_port                = var.gateway_admin_port
  to_port                  = var.gateway_admin_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.gateway.id
  source_security_group_id = aws_security_group.ops.id
}

resource "aws_security_group_rule" "gateway_egress_api" {
  description              = "F3: verified request forwarding to the API"
  type                     = "egress"
  from_port                = var.api_port
  to_port                  = var.api_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.gateway.id
  source_security_group_id = aws_security_group.api.id
}

resource "aws_security_group_rule" "gateway_egress_ca" {
  description              = "F4: staple refresh + approved certificate operations only"
  type                     = "egress"
  from_port                = var.ca_port
  to_port                  = var.ca_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.gateway.id
  source_security_group_id = aws_security_group.ca.id
}

resource "aws_security_group_rule" "gateway_egress_endpoints" {
  description              = "F7: KMS, Secrets Manager, SSM via interface endpoints"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.gateway.id
  source_security_group_id = aws_security_group.endpoints.id
}

resource "aws_security_group_rule" "gateway_egress_logs_nat" {
  description       = "CloudWatch Logs egress via NAT (endpoint set reduced per ADR-006)"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.gateway.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "gateway_dns_udp" {
  description       = "DNS to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = aws_security_group.gateway.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "gateway_dns_tcp" {
  description       = "DNS over TCP to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  security_group_id = aws_security_group.gateway.id
  cidr_blocks       = [var.vpc_cidr]
}

# Keycloak tier (F5, F6, F10–F12)

resource "aws_security_group_rule" "keycloak_ingress_from_api" {
  description              = "F5: token issuance/validation endpoints for the API"
  type                     = "ingress"
  from_port                = var.keycloak_port
  to_port                  = var.keycloak_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.keycloak.id
  source_security_group_id = aws_security_group.api.id
}

resource "aws_security_group_rule" "keycloak_ingress_admin_from_ops" {
  description              = "Realm administration via the config-as-code pipeline"
  type                     = "ingress"
  from_port                = var.keycloak_port
  to_port                  = var.keycloak_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.keycloak.id
  source_security_group_id = aws_security_group.ops.id
}

resource "aws_security_group_rule" "keycloak_egress_rds" {
  description              = "F6: Keycloak own database"
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.keycloak.id
  source_security_group_id = aws_security_group.rds.id
}

# F10/F11: LDAPS clinic federation, registry-scoped; the concrete IP allowlist is applied at deployment (§5.1).
resource "aws_security_group_rule" "keycloak_egress_ldaps_clinic" {
  description       = "F10/F11: clinic federation LDAPS via NAT - registry-scoped at deployment"
  type              = "egress"
  from_port         = 636
  to_port           = 636
  protocol          = "tcp"
  security_group_id = aws_security_group.keycloak.id
  cidr_blocks       = var.clinic_federation_cidrs
}

# F12: state SAML IdPs.
# quay.io pulls share this permission; EC2 rejects a second identical 443 rule (InvalidPermission.Duplicate).
resource "aws_security_group_rule" "keycloak_egress_saml" {
  description       = "F12: state SAML IdPs and quay.io image pulls via NAT"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.keycloak.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "keycloak_egress_endpoints" {
  description              = "F7: AWS services via interface endpoints"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.keycloak.id
  source_security_group_id = aws_security_group.endpoints.id
}

resource "aws_security_group_rule" "keycloak_dns_udp" {
  description       = "DNS to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = aws_security_group.keycloak.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "keycloak_dns_tcp" {
  description       = "DNS over TCP to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  security_group_id = aws_security_group.keycloak.id
  cidr_blocks       = [var.vpc_cidr]
}

# API tier (F3, F5, F6)

resource "aws_security_group_rule" "api_ingress_from_alb" {
  description              = "F3 (wave 1 shape): direct ALB to API. Gateway replaces this when deployed."
  type                     = "ingress"
  from_port                = var.api_port
  to_port                  = var.api_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.api.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "api_ingress_from_gateway" {
  description              = "F3: only the gateway calls the API (rule active once gateway deploys)"
  type                     = "ingress"
  from_port                = var.api_port
  to_port                  = var.api_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.api.id
  source_security_group_id = aws_security_group.gateway.id
}

resource "aws_security_group_rule" "api_egress_rds" {
  description              = "F6: patient/identity data store"
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.api.id
  source_security_group_id = aws_security_group.rds.id
}

resource "aws_security_group_rule" "api_egress_keycloak" {
  description              = "F5: JWT validation"
  type                     = "egress"
  from_port                = var.keycloak_port
  to_port                  = var.keycloak_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.api.id
  source_security_group_id = aws_security_group.keycloak.id
}

resource "aws_security_group_rule" "api_egress_endpoints" {
  description              = "F7: AWS services via interface endpoints"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.api.id
  source_security_group_id = aws_security_group.endpoints.id
}

resource "aws_security_group_rule" "api_dns_udp" {
  description       = "DNS to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = aws_security_group.api.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "api_dns_tcp" {
  description       = "DNS over TCP to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  security_group_id = aws_security_group.api.id
  cidr_blocks       = [var.vpc_cidr]
}

# Fargate pulls egress over the task ENI; without this rule the first deploy fails CannotPullContainerError.
resource "aws_security_group_rule" "api_egress_https_registry" {
  description       = "ECR pulls and CloudWatch Logs (awslogs) egress via NAT (endpoint set reduced per ADR-006)"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.api.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# RDS tier (F6, ADR-009)

resource "aws_security_group_rule" "rds_ingress_from_api" {
  description              = "F6: PostgreSQL from the API tier only"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.api.id
}

resource "aws_security_group_rule" "rds_ingress_from_keycloak" {
  description              = "F6: PostgreSQL from Keycloak only"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.keycloak.id
}

# CA tier (F4, ADR-011)

resource "aws_security_group_rule" "ca_ingress_from_gateway" {
  description              = "F4: staple refresh + approved ops only"
  type                     = "ingress"
  from_port                = var.ca_port
  to_port                  = var.ca_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ca.id
  source_security_group_id = aws_security_group.gateway.id
}

resource "aws_security_group_rule" "ca_egress_endpoints" {
  description              = "F7: KMS for key operations via interface endpoints"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ca.id
  source_security_group_id = aws_security_group.endpoints.id
}

resource "aws_security_group_rule" "ca_dns_udp" {
  description       = "DNS to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = aws_security_group.ca.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "ca_dns_tcp" {
  description       = "DNS over TCP to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  security_group_id = aws_security_group.ca.id
  cidr_blocks       = [var.vpc_cidr]
}

# Ops tier (F13–F15, ADR-013)

# F13/F14: onboarding-pipeline federation pre-checks via NAT.
resource "aws_security_group_rule" "ops_egress_ldaps" {
  description       = "F13: LDAPS pre-checks via NAT - registry-scoped at deployment"
  type              = "egress"
  from_port         = 636
  to_port           = 636
  protocol          = "tcp"
  security_group_id = aws_security_group.ops.id
  cidr_blocks       = var.clinic_federation_cidrs
}

resource "aws_security_group_rule" "ops_egress_keycloak_admin" {
  description              = "Pipeline-driven realm administration"
  type                     = "egress"
  from_port                = var.keycloak_port
  to_port                  = var.keycloak_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ops.id
  source_security_group_id = aws_security_group.keycloak.id
}

resource "aws_security_group_rule" "ops_egress_ca_ops" {
  description              = "Pipeline-driven certificate operations"
  type                     = "egress"
  from_port                = var.ca_port
  to_port                  = var.ca_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ops.id
  source_security_group_id = aws_security_group.ca.id
}

# F15 to the Wazuh manager; 100.64.0.0/10 is the Tailscale CGNAT range, exits via NAT to the tailnet (sanitized per ADR-012).
resource "aws_security_group_rule" "ops_egress_wazuh" {
  description       = "F15: Wazuh manager ingestion ports over the tailnet"
  type              = "egress"
  from_port         = 1514
  to_port           = 1515
  protocol          = "tcp"
  security_group_id = aws_security_group.ops.id
  cidr_blocks       = ["100.64.0.0/10"]
}

resource "aws_security_group_rule" "ops_egress_endpoints" {
  description              = "F7: AWS services via interface endpoints (SSM, Secrets Manager, KMS)"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ops.id
  source_security_group_id = aws_security_group.endpoints.id
}

# clinic_federation_cidrs defaults to 0.0.0.0/0, so a separate F13/F14 443 rule is the same permission.
resource "aws_security_group_rule" "ops_egress_logs_nat" {
  description       = "F13/F14 federation pre-checks and CloudWatch Logs read via NAT (endpoint set reduced per ADR-006)"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.ops.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ops_dns_udp" {
  description       = "DNS to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = aws_security_group.ops.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "ops_dns_tcp" {
  description       = "DNS over TCP to the VPC resolver"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  security_group_id = aws_security_group.ops.id
  cidr_blocks       = [var.vpc_cidr]
}

# Endpoints tier (F7)

resource "aws_security_group_rule" "endpoints_ingress_from_api" {
  description              = "F7: interface endpoints serve the API tier"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints.id
  source_security_group_id = aws_security_group.api.id
}

resource "aws_security_group_rule" "endpoints_ingress_from_keycloak" {
  description              = "F7: interface endpoints serve Keycloak"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints.id
  source_security_group_id = aws_security_group.keycloak.id
}

resource "aws_security_group_rule" "endpoints_ingress_from_ca" {
  description              = "F7: interface endpoints serve the CA tier (KMS)"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints.id
  source_security_group_id = aws_security_group.ca.id
}

resource "aws_security_group_rule" "endpoints_ingress_from_ops" {
  description              = "F7: interface endpoints serve the ops tier (SSM, CloudWatch, S3)"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints.id
  source_security_group_id = aws_security_group.ops.id
}

resource "aws_security_group_rule" "endpoints_ingress_from_gateway" {
  description              = "F7: interface endpoints serve the gateway tier"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints.id
  source_security_group_id = aws_security_group.gateway.id
}
