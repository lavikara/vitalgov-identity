variable "project_name" {
  description = "Name of the application/project."
  type        = string
  default     = "vitalgov"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "aws_region" {
  description = "AWS region where the cluster runs."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to compute resources."
  type        = map(string)
  default     = {}
}

variable "app_subnet_ids" {
  description = "Private application subnet IDs for the Fargate tasks."
  type        = list(string)
}

variable "target_group_arn" {
  description = "ALB target group ARN for services with attach_to_target_group = true."
  type        = string
  default     = null
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for interactive troubleshooting."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention for container logs."
  type        = number
  default     = 90
}

variable "services" {
  description = <<-EOT
    Map of Fargate services to run in the shared cluster, keyed by service
    name. Each entry defines its own image, sizing, env/secrets and security
    group so the API, Keycloak and (later) the gateway can differ.
  EOT
  type = map(object({
    container_name    = string
    container_image   = string
    container_port    = number
    cpu               = number
    memory            = number
    desired_count     = number
    health_check_path = string
    # Null uses wget against health_check_path; images without wget must supply this.
    health_check_cmd       = optional(string)
    security_group_id      = string
    attach_to_target_group = bool
    environment            = map(string)
    secrets                = map(string)
  }))
}
