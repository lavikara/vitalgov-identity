# VitalGov infrastructure - `infrastructure/terraform`

Wave-1 infrastructure for the VitalGov capstone, all in `af-south-1` (brief
requirement, residency ADR-012). Design rationale lives in `docs/cloud/`.

## Layout

```
terraform/               root config (wiring, variables, outputs)
  state/                 bootstrap: state bucket + lock table
  logs/                  CloudTrail + ALB log bucket
  iam/                   GitHub OIDC deploy role (scoped to vitalgov-*)
  Networking/            VPC, 4-tier subnets, single NAT, flow logs
  SecurityGroups/        §7.2 matrix from network-traffic-flows.md
  VpcEndpoints/          S3 gateway + 4 interface endpoints (KMS, SM, SSM×2)
  Alb/                   internet-facing ALB + target group
  Ecr/                   vitalgov-api repository
  Ecs/                   shared cluster; API + Keycloak Fargate services
  Database/              RDS PostgreSQL 15 (data subnets, no NAT route)
  SecretsManager/        db-host/name/user/password, jwt, keycloak-admin
  S3/                    realm-backups bucket (Keycloak exports)
  Observability/         CloudTrail (CMK), 5 alarms, SNS, budget
  Ops/                   single ops host: Tailscale connector + Wazuh agent
  Pki/                   CA CMK; placeholder host gated by create_ca_host
  Acm/                   dormant until a domain exists
```

## Deployment gate

**No `terraform apply` before the four-discipline review signs off (D1).**
Writing and validating Terraform is allowed; provisioning is not.

## Bootstrap (first apply, after review sign-off)

Secrets are supplied as `TF_VAR_*` environment variables; never CLI args:

```bash
export TF_VAR_db_username="vitalgov"
export TF_VAR_db_password="$(openssl rand -base64 24 | tr -d '/')"  # RDS rejects / @ " and space
export TF_VAR_jwt_secret="$(openssl rand -base64 48)"
export TF_VAR_keycloak_admin_password="$(openssl rand -base64 24)"
export TF_VAR_container_image="<account>.dkr.ecr.af-south-1.amazonaws.com/vitalgov-api:latest"
export TF_VAR_github_org_id="<numeric org id>"
export TF_VAR_github_repo_id="<numeric repo id>"

cd infrastructure/terraform

# 1. The s3 backend cannot serve an apply before the bucket exists, so swap in a local backend first
cp backend.tf /tmp/backend.tf.s3
echo 'terraform { backend "local" {} }' > backend.tf
terraform init -reconfigure
terraform apply -target=module.state -auto-approve
cp /tmp/backend.tf.s3 backend.tf

# 2. Migrate to the remote backend
terraform init -migrate-state \
  -backend-config="bucket=vitalgov-production-tfstate" \
  -backend-config="key=vitalgov/production/terraform.tfstate" \
  -backend-config="region=af-south-1"
# Fallback (seen 15 Oct): if step 2 says success but the bucket is empty, `aws s3 cp terraform.tfstate s3://vitalgov-production-tfstate/vitalgov/production/terraform.tfstate --sse AES256`, then rerun step 2 with -reconfigure.

# 3. Apply in waves; each wave must converge before the next
terraform apply -target=module.networking
terraform apply -target=module.security_groups
terraform apply -target=module.vpc_endpoints
terraform apply -target=module.logs
terraform apply -target=module.alb
terraform apply -target=module.ecr
terraform apply -target=module.rds
terraform apply -target=module.secrets_manager
terraform apply -target=module.ecs
terraform apply -target=module.observability
terraform apply -target=module.ops
terraform apply -target=module.pki
terraform apply -target=module.iam

# 4. Full stack
terraform apply
```

Profile: `admin` (Team 2 AWS account). Region fixed at `af-south-1`.

## Cost

af-south-1 on-demand, always-on shape (~730 h/month, no Reserved/Spot):

| Service | Shape | Est. USD/mo |
|---|---|---|
| NAT gateway | 1 × + data | ~$35 |
| ALB | 1 × + LCU | ~$22 |
| ECS Fargate | 2 services × 0.25 vCPU / 512 MB | ~$70 |
| RDS PostgreSQL | db.t3.micro, 20 GB gp3, Single-AZ | ~$16 |
| VPC endpoints | 4 interface × 1 AZ + S3 gateway (free) | ~$30 |
| EC2 ops host | t3.small, Tailscale + Wazuh agent (CA host off until I-007) | ~$15 |
| CloudTrail, S3, CW logs, SNS, budget | small volumes | ~$7 |
| **Total** | | **~$195** |

Budget alarm: $200 ceiling, alerts at 80% ($160) and 100%. Notification
emails are not committed; export `TF_VAR_budget_alert_emails='["<address>"]'`
before every plan and apply. Never put it in `terraform.tfvars`: a tfvars
entry outranks the env var and silently wins, which left every alarm and the
budget notifying nobody until it was removed.

### What was cut to get here (and what each cut saved)

| Cut | Saving | Where |
|---|---|---|
| Interface endpoints 11 → 4, both AZs → 1 AZ | ~$130 | Endpoints cost ~$7.31/endpoint/**AZ**; ECR/CW/ECS/STS now ride the NAT. `endpoint_az_count = 2` restores dual-AZ |
| Keycloak task 0.5 vCPU/1 GB → 0.25/512 MB | ~$30 | Floor for 3 test realms; raise if review loads more |
| RDS enhanced monitoring 60 s → off | ~$20 | Per-vCPU-hour charge; basic CloudWatch + alarms remain |
| CA placeholder host off until I-007 | ~$8 | `create_ca_host = false`; CMK still created |

The Tailscale connector and Wazuh log-forwarder were consolidated into one `t3.small`
host (ADR-013): co-located because the forwarder already depends on the tailnet the
connector provides. This costs ~$4 more than the earlier two-host split but halves the
ops configuration surface.

### Levers the review can still pull

| Lever | Extra saving | Trade-off |
|---|---|---|
| Keycloak on t3.micro EC2 instead of Fargate | ~$27 | Contradicts ADR-008 Fargate rec; loses circuit-breaker/rollback |
| Secrets Manager endpoint → NAT | ~$7 | Credentials traverse NAT (still TLS) |
| S3 gateway covers ECR layers already | - | Image pulls via NAT add minor data cost |

Realistic floor with the brief's ALB + mTLS + private tiers intact: ~$175.
Below that requires dropping brief-mandated components.

## Teardown

See [TEARDOWN.md](../../TEARDOWN.md).
