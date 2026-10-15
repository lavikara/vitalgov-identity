# Teardown Runbook - VitalGov Capstone Environment

> The Team 2 environment is live in `af-south-1` (166 resources, applied
> 15 Oct 2026). This is the teardown procedure; fill the date row below
> when it is executed.

| | |
|---|---|
| **Date of teardown** | _pending_ |
| **AWS account** | Team 2 account, user `admin`, profile `admin` |
| **Primary region** | `af-south-1` |
| **Profile used** | `admin` |
| **State backend** | `s3://vitalgov-production-tfstate/vitalgov/production/terraform.tfstate` |
| **Terraform** | v1.16.0 |

## Capstone-friendly choices already baked in

- `skip_final_snapshot = true` on RDS (no orphaned final snapshot)
- `deletion_protection = false` default on RDS + ALB (`enable_deletion_protection` var)
- `force_destroy = true` on the realm-backups bucket (S3 module)
- CA host off by default (`create_ca_host = false`), one less host to remove

## Still requiring manual action

- **State bucket**, `prevent_destroy = true` by design. Remove the lifecycle
  block or `terraform state rm` it before the final destroy.
- **Log bucket**, versioned; `force_destroy = false`, so empty object
  versions may need a manual pass.
- **ECR images**, `aws_ecr_repository` has no force_destroy; empty the repo
  first: `aws ecr delete-repository --repository-name vitalgov-api --force`
- **SSM parameters**, `/vitalgov/production/tailscale-auth-key` and
  `wazuh-manager-ip` are state-tracked, but verify none remain:
  `aws ssm get-parameters-by-path --path /vitalgov --recursive`
- **CloudWatch log groups**, `/ecs/vitalgov/*`, `/aws/vpc/flowlogs/*`,
  `/aws/rds/instance/*` are partly state-tracked; verify none remain.
- **KMS keys**, CA CMK and trail CMK have 7-14 day deletion windows;
  schedule deletion then confirm.
- **Budget + SNS**, deleted via Terraform, but AWS budgets can linger a few
  hours; confirm in Cost Explorer.

## Runbook order

1. `terraform destroy` (full stack). Watch for the state-bucket lifecycle error.
2. If step 1 stalls on the state bucket: comment the lifecycle block,
   `terraform apply`, re-run destroy.
3. Empty + delete remaining buckets (log versions, ECR images).
4. Confirm zero spend: Cost Explorer, last 1 day, filter `vitalgov-*` tags.
5. Record the results in the table above.

## Data-retention note

Per ADR-012 (residency) and the brief: this is a capstone environment with
synthetic data. Before destroying, confirm with the team that no evidence
artefacts (screenshots, logs, exports) are still needed for the portfolio.
Realm exports in the backups bucket are the primary evidence source.
