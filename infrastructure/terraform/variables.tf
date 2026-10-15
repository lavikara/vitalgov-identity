variable "project_name" {
  description = "Name of the application/project."
  type        = string
  default     = "vitalgov"
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "aws_region" {
  description = "AWS region where all resources are deployed. Brief requires af-south-1."
  type        = string
  default     = "af-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile for local runs. CI passes an empty string to use OIDC credentials instead."
  type        = string
  default     = "admin"
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones."
  type        = list(string)
  default     = ["af-south-1a", "af-south-1b"]
}

# Tier CIDRs follow ip-addressing-plan.md; subnets right-sized to /24 (I-009 resolved and applied).
variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (ALB + NAT placement)."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "app_subnet_cidrs" {
  description = "Private application subnet CIDRs (ECS, Keycloak, ops host)."
  type        = list(string)
  default     = ["10.20.16.0/24", "10.20.32.0/24"]
}

variable "data_subnet_cidrs" {
  description = "Private data subnet CIDRs (RDS). No route to the internet (ADR-009)."
  type        = list(string)
  default     = ["10.20.64.0/24", "10.20.65.0/24"]
}

variable "pki_subnet_cidrs" {
  description = "Restricted PKI/CA tier CIDRs (reserved range, ADR-007). No NAT route."
  type        = list(string)
  default     = ["10.20.96.0/24", "10.20.97.0/24"]
}

variable "domain_name" {
  description = "Domain name for the ACM certificate on the team's free DNS service; validation CNAMEs are added manually at that provider (see the Acm module's validation_record output)."
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (optional)."
  type        = string
  default     = null
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB and RDS."
  type        = bool
  default     = false
}

variable "container_image" {
  description = "Docker image URI for the ECS application container."
  type        = string
}

variable "keycloak_image" {
  description = "Keycloak container image. Default matches the brief (23.0); D1 review may ratify 26.8.0 to match the lab instance."
  type        = string
  default     = "quay.io/keycloak/keycloak:23.0"
}

variable "container_port" {
  description = "Port exposed by the application container."
  type        = number
  default     = 3000
}

variable "keycloak_port" {
  description = "Port exposed by the Keycloak container."
  type        = number
  default     = 8080
}

variable "gateway_admin_port" {
  description = "Admin/API port of the API gateway tier (APISIX default 9180). Not deployed in wave 1."
  type        = number
  default     = 9180
}

variable "ca_port" {
  description = "CA/OCSP service port on the PKI tier. Final value follows the I-007 CA decision."
  type        = number
  default     = 8551
}

variable "ecr_repository_name" {
  description = "ECR repository name. Must match the name the application CI pushes to."
  type        = string
  default     = "vitalgov-api"
}

variable "ecs_service_name" {
  description = "ECS service name for the API. Must match what application CI calls in update-service."
  type        = string
  default     = "vitalgov-api-production"
}

variable "api_cpu" {
  description = "CPU units allocated to the API task."
  type        = number
  default     = 256
}

variable "api_memory" {
  description = "Memory in MiB allocated to the API task."
  type        = number
  default     = 512
}

variable "keycloak_cpu" {
  description = "CPU units allocated to the Keycloak task. 256 covers the capstone's three test realms; raise if the review loads more."
  type        = number
  default     = 256
}

variable "keycloak_memory" {
  description = "Memory in MiB allocated to the Keycloak task. 512 is the floor for the JVM; raise to 1024 if realm count grows."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of tasks per ECS service."
  type        = number
  default     = 1
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for interactive troubleshooting."
  type        = bool
  default     = false
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "vitalgov"
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL master password. Pass as TF_VAR_db_password, never a CLI arg."
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret. Pass as TF_VAR_jwt_secret."
  type        = string
  sensitive   = true
}

variable "keycloak_admin_username" {
  description = "Bootstrap admin username for the Keycloak master realm."
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Bootstrap admin password for Keycloak. Pass as TF_VAR_keycloak_admin_password."
  type        = string
  sensitive   = true
}

variable "rds_monitoring_interval" {
  description = "RDS enhanced monitoring interval in seconds (charged per vCPU-hour). 0 = basic CloudWatch monitoring only."
  type        = number
  default     = 0
}

variable "backup_retention_period" {
  description = "RDS automated backup retention in days. Open decision: subject to the NHA retention question (I-011)."
  type        = number
  default     = 7
}

variable "log_retention_days" {
  description = "CloudWatch log retention. Open decision pending NHA retention (I-011)."
  type        = number
  default     = 90
}

variable "budget_limit_usd" {
  description = "Monthly budget ceiling in USD. ~$190 estimate at af-south-1 on-demand; 80% alert fires at $152."
  type        = string
  default     = "200"
}

variable "budget_alert_emails" {
  description = "Emails notified at 80%/100% of budget and on CloudWatch alarms. Empty by default; set via TF_VAR_budget_alert_emails; do not commit personal addresses."
  type        = list(string)
  default     = []
}

variable "github_org" {
  description = "GitHub organization or username owning the infrastructure repository."
  type        = string
  default     = "lavikara"
}

variable "github_repo" {
  description = "Infrastructure repository name."
  type        = string
  default     = "vitalgov-identity"
}

variable "github_org_id" {
  description = "Numeric GitHub organization ID."
  type        = string
}

variable "github_repo_id" {
  description = "Numeric GitHub repository ID."
  type        = string
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key for the ops-tier connector. Empty until rotation completes (I-023); Parameter Store rejects empty values."
  type        = string
  default     = "pending-I-023"
  sensitive   = true
}

variable "wazuh_manager_ip" {
  description = "Wazuh manager address (tailnet IP or hostname) the log-forwarder ships to. Empty until the manager is reachable (I-024); Parameter Store rejects empty values."
  type        = string
  default     = "unset"
}

variable "create_ca_host" {
  description = "Create the placeholder CA host in the PKI tier. False until the I-007 CA software decision (owner: Ismail); the CA CMK is created either way."
  type        = bool
  default     = false
}
