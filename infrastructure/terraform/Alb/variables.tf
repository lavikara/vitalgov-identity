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
    error_message = "Environment must be development, staging, or production."
  }
}

variable "common_tags" {
  description = "Common tags applied to ALB resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID where the target group is deployed."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs the ALB is deployed into."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least two public subnets should be provided."
  }
}

variable "internal" {
  description = "Whether the ALB is internal (private) or internet-facing."
  type        = bool
  default     = false
}

variable "container_port" {
  description = "Port the gateway/API container listens on. Used as the target group port."
  type        = number
  default     = 3000
}

variable "health_check_path" {
  description = "HTTP path used by the target group health check."
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Approximate time, in seconds, between target group health checks."
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Time, in seconds, to wait for a target group health check response."
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Number of consecutive successful health checks before a target is healthy."
  type        = number
  default     = 3
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed health checks before a target is unhealthy."
  type        = number
  default     = 3
}

variable "health_check_matcher" {
  description = "HTTP status codes considered a successful health check response."
  type        = string
  default     = "200"
}

variable "deregistration_delay" {
  description = "Seconds the ALB waits before deregistering a draining target."
  type        = number
  default     = 30
}

variable "enable_https" {
  description = "Whether to create an HTTPS listener. Requires certificate_arn to also be set."
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "ACM certificate ARN used by the HTTPS listener. Required when enable_https is true."
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "SSL policy applied to the HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "idle_timeout" {
  description = "Time, in seconds, the ALB keeps an idle connection open."
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection on the ALB."
  type        = bool
  default     = false
}

variable "alb_security_group_id" {
  description = "Security group attached to the ALB (owned by the SecurityGroups module)."
  type        = string
}

variable "access_log_bucket" {
  description = "S3 bucket for ALB access logs. Null disables access logging."
  type        = string
  default     = null
}

variable "access_log_prefix" {
  description = "Prefix within the access log bucket."
  type        = string
  default     = "alb"
}
