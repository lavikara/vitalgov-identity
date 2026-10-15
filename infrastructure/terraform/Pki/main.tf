# PKI tier (ADR-007): CMK always created; host gated by create_ca_host until I-007 (Ismail). No public IP, no NAT (V10), SSM only.

locals {
  common_tags = merge(
    var.common_tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "PKI"
    }
  )
}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "al2023" {
  count = var.create_ca_host ? 1 : 0

  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_kms_key" "ca" {
  description             = "${var.project_name}-${var.environment} issuing CA key material"
  deletion_window_in_days = 14
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "RootAdmin"
          Effect    = "Allow"
          Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
          Action    = "kms:*"
          Resource  = "*"
        },
        {
          # Input, not interpolated: creates the module.iam dependency edge; KMS rejects roles that do not exist yet.
          Sid       = "DeployRoleAdmin"
          Effect    = "Allow"
          Principal = { AWS = var.deploy_role_arn }
          Action = [
            "kms:DescribeKey",
            "kms:GetKeyPolicy",
            "kms:PutKeyPolicy",
            "kms:TagResource",
            "kms:UntagResource",
            "kms:EnableKeyRotation"
          ]
          Resource = "*"
        }
      ],
      # Emitted only when the host exists; KMS rejects unresolvable principals (create_ca_host defaults to false).
      var.create_ca_host ? [
        {
          Sid       = "CAHostUse"
          Effect    = "Allow"
          Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-ca-host" }
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
          ]
          Resource = "*"
        }
      ] : []
    )
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ca-key"
    }
  )
}

resource "aws_kms_alias" "ca" {
  name          = "alias/${var.project_name}-${var.environment}-ca"
  target_key_id = aws_kms_key.ca.key_id
}

resource "aws_iam_role" "ca_host" {
  count = var.create_ca_host ? 1 : 0

  name = "${var.project_name}-${var.environment}-ca-host"

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

resource "aws_iam_role_policy_attachment" "ca_ssm" {
  count = var.create_ca_host ? 1 : 0

  role       = aws_iam_role.ca_host[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ca_kms" {
  count = var.create_ca_host ? 1 : 0

  name = "${var.project_name}-${var.environment}-ca-kms"
  role = aws_iam_role.ca_host[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      Resource = aws_kms_key.ca.arn
    }]
  })
}

resource "aws_iam_instance_profile" "ca_host" {
  count = var.create_ca_host ? 1 : 0

  name = "${var.project_name}-${var.environment}-ca-host"
  role = aws_iam_role.ca_host[0].name

  tags = local.common_tags
}

resource "aws_instance" "ca_host" {
  count = var.create_ca_host ? 1 : 0

  ami           = data.aws_ssm_parameter.al2023[0].value
  instance_type = var.instance_type
  subnet_id     = var.pki_subnet_ids[0]

  vpc_security_group_ids = [var.ca_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ca_host[0].name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    kms_key_id            = aws_kms_key.ca.arn
    delete_on_termination = true
  }

  # No package installs: the PKI subnet has no NAT route (V10); artifacts arrive via SSM or the S3 gateway.
  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    systemctl enable --now amazon-ssm-agent
    cat > /etc/${var.project_name}-ca-README <<'EOF'
    ${var.project_name} CA host - software selection pending issue I-007.
    Key material encrypts under KMS alias ${var.project_name}-${var.environment}-ca.
    No inbound SSH; use SSM Session Manager. No NAT route in this tier (V10).
    EOF
  EOT

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ca-host"
      Role = "Issuing CA host (software pending I-007)"
      Tier = "PKI"
    }
  )
}
