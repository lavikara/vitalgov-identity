# Non-secret defaults; secrets go through TF_VAR_* environment variables (names in variables.tf).

environment = "production"
aws_profile = "admin"
aws_region  = "af-south-1"

vpc_cidr           = "10.20.0.0/16"
availability_zones = ["af-south-1a", "af-south-1b"]

# Subnet CIDRs per docs/cloud/ip-addressing-plan.md §3 + §6
public_subnet_cidrs = ["10.20.0.0/24", "10.20.1.0/24"]
app_subnet_cidrs    = ["10.20.16.0/24", "10.20.32.0/24"]
data_subnet_cidrs   = ["10.20.64.0/24", "10.20.65.0/24"]
pki_subnet_cidrs    = ["10.20.96.0/24", "10.20.97.0/24"]

db_name                 = "vitalgov"
backup_retention_period = 7  # open decision (I-011)
log_retention_days      = 90 # open decision (I-011)

budget_limit_usd = "200"
# Budget emails are never written to this file: export TF_VAR_budget_alert_emails as a JSON list before every plan and apply. A tfvars entry here would outrank that env var.

github_org  = "lavikara"
github_repo = "vitalgov-identity"

# Host off until the I-007 CA decision; the CMK is created regardless.
create_ca_host = false
