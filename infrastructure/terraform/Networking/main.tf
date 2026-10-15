locals {
  common_tags = merge(
    var.common_tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "Networking"
    }
  )
}

resource "aws_vpc" "vitalgov" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

resource "aws_internet_gateway" "vitalgov" {
  vpc_id = aws_vpc.vitalgov.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}

# Explicit CIDRs from ip-addressing-plan.md §3 (not cidrsubnet): public/app/data/pki tiers.

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.vitalgov.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
      Type = "Public"
    }
  )
}

resource "aws_subnet" "app" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.vitalgov.id
  cidr_block        = var.app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-app-${var.availability_zones[count.index]}"
      Type = "Application"
    }
  )
}

resource "aws_subnet" "data" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.vitalgov.id
  cidr_block        = var.data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-data-${var.availability_zones[count.index]}"
      Type = "Data"
    }
  )
}

# Restricted CA tier (ADR-007): no NAT route (KMS endpoint only), SSM-only admin (ADR-011).
resource "aws_subnet" "pki" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.vitalgov.id
  cidr_block        = var.pki_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-pki-${var.availability_zones[count.index]}"
      Type = "PKI"
    }
  )
}

# Single NAT in AZ 1 (ADR-010 cost trade-off; review may require a second for AZ-resilient egress).

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip"
    }
  )
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat"
    }
  )

  depends_on = [aws_internet_gateway.vitalgov]
}

# public → IGW, app → NAT, data & pki → local only (deliberately no 0.0.0.0/0 route).

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vitalgov.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
      Type = "Public"
    }
  )
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vitalgov.id
}

resource "aws_route_table" "app" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.vitalgov.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-app-rt-${var.availability_zones[count.index]}"
      Type = "Application"
    }
  )
}

resource "aws_route" "app_nat" {
  count = length(var.availability_zones)

  route_table_id         = aws_route_table.app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.vitalgov.id

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.project_name}-${var.environment}-data-rt"
      Type   = "Data"
      Egress = "None"
    }
  )
}

resource "aws_route_table" "pki" {
  vpc_id = aws_vpc.vitalgov.id

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.project_name}-${var.environment}-pki-rt"
      Type   = "PKI"
      Egress = "None"
    }
  )
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

resource "aws_route_table_association" "data" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

resource "aws_route_table_association" "pki" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.pki[count.index].id
  route_table_id = aws_route_table.pki.id
}

# VPC flow logs → CloudWatch Logs (brief monitoring requirement).

resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.vitalgov.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  # cloud-watch-logs requires an IAM role; omitting it fails creation.
  iam_role_arn             = aws_iam_role.flow_logs.arn
  max_aggregation_interval = 60

  # Policy must exist first or delivery is rejected on create.
  depends_on = [aws_iam_role_policy.flow_logs]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-${var.environment}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.project_name}-${var.environment}-vpc-flow-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups"
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}
