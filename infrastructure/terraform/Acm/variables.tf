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

variable "domain_name" {
  description = "Domain name for the ACM certificate."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to ACM resources."
  type        = map(string)
  default     = {}
}
