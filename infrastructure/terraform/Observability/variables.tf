variable "project_name" {
  description = "Name of the application/project."
  type        = string
  default     = "vitalgov"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to observability resources."
  type        = map(string)
  default     = {}
}

variable "alb_id" {
  description = "ALB resource ID, in LoadBalancer dimension form (app/name/id)."
  type        = string
}

variable "target_group_id" {
  description = "Target group resource ID, in targetgroup/name/id form."
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name (the API service)."
  type        = string
}

variable "ecs_desired_count" {
  description = "Expected number of running API tasks, used as the low-water alarm threshold."
  type        = number
  default     = 1
}

variable "db_instance_id" {
  description = "RDS instance identifier."
  type        = string
}

variable "budget_limit_usd" {
  description = "Monthly budget ceiling in USD for the whole project."
  type        = string
  default     = "250"
}

variable "budget_alert_emails" {
  description = "Emails to notify at 80% and 100% of budget. Alarm emails share this list."
  type        = list(string)
  default     = []
}

variable "log_bucket_name" {
  description = "S3 bucket receiving CloudTrail logs (managed by the logs module)."
  type        = string
}

variable "deploy_role_arn" {
  description = "ARN of the GitHub Actions deploy role, passed (not interpolated) so the trail KMS key policy has a real dependency edge on module.iam."
  type        = string
}
