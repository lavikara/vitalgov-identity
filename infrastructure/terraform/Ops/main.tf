# Ops tier (ADR-013): one host (Tailscale connector + Wazuh agent), no public IP, SSM only; key in SSM, I-023 pending.

locals {
  common_tags = merge(
    var.common_tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "Ops"
    }
  )
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ops_host" {
  name = "${var.project_name}-${var.environment}-ops-host"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ops_ssm" {
  role       = aws_iam_role.ops_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# F15: agent reads API events from CloudWatch Logs (egress via shared NAT, per ADR-006).
resource "aws_iam_role_policy" "ops_logs_read" {
  name = "${var.project_name}-${var.environment}-ops-logs-read"
  role = aws_iam_role.ops_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DiscoverLogGroups"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        Sid    = "ReadServiceLogs"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogStreams",
          "logs:FilterLogEvents",
          "logs:GetLogEvents",
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}/${var.environment}/*"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "ops_host" {
  name = "${var.project_name}-${var.environment}-ops-host"
  role = aws_iam_role.ops_host.name

  tags = local.common_tags
}

resource "aws_ssm_parameter" "tailscale_auth_key" {
  name  = "/${var.project_name}/${var.environment}/tailscale-auth-key"
  type  = "SecureString"
  value = var.tailscale_auth_key

  tags = local.common_tags
}

resource "aws_ssm_parameter" "wazuh_manager_ip" {
  name  = "/${var.project_name}/${var.environment}/wazuh-manager-ip"
  type  = "String"
  value = var.wazuh_manager_ip

  tags = local.common_tags
}

resource "aws_instance" "ops" {
  ami           = data.aws_ssm_parameter.al2023.value
  instance_type = "t3.small" # Wazuh agent ~1 GiB + Tailscale + log-buffer headroom
  subnet_id     = var.app_subnet_ids[0]

  vpc_security_group_ids = [var.ops_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ops_host.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    systemctl enable --now amazon-ssm-agent
    # Installed by the ops pipeline via SSM once the rotated key (I-023) and manager address are in place.
    echo "${var.project_name}-ops bootstrapped $(date -u +%FT%TZ)" > /var/log/${var.project_name}-bootstrap.log
  EOT

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ops"
      Role = "Tailscale connector + Wazuh agent (ADR-013 / F15)"
      Tier = "Ops"
    }
  )
}
