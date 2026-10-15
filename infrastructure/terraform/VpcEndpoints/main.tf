# Inventory + documented deviation: docs/cloud/aws-architecture.md §4.7 (ADR-006, I-005, I-028).

locals {
  common_tags = merge(
    var.common_tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "VpcEndpoints"
    }
  )

  interface_endpoints = {
    kms            = "kms"
    secretsmanager = "secretsmanager"
    ssm            = "ssm"
    ssmmessages    = "ssmmessages"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    var.app_route_table_ids,
    var.data_route_table_ids,
    var.pki_route_table_ids,
  )

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-s3-endpoint"
    }
  )
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = slice(var.app_subnet_ids, 0, var.endpoint_az_count)
  security_group_ids  = [var.endpoints_security_group_id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${each.key}-endpoint"
    }
  )
}
