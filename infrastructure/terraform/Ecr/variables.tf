variable "project_name" {
  description = "Name of the application/project."
  type        = string
  default     = "vitalgov"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "ecr_repository_name" {
  description = "ECR repository name. Must match the name the application CI pushes to."
  type        = string
  default     = "vitalgov-api"
}

variable "common_tags" {
  description = "Common tags applied to ECR resources."
  type        = map(string)
  default     = {}
}
