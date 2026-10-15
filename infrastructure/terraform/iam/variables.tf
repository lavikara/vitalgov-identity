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
  description = "AWS region where the deploy role operates."
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username owning the infrastructure repository."
  type        = string
}

variable "github_repo" {
  description = "Infrastructure repository name."
  type        = string
}

variable "github_org_id" {
  description = "Numeric GitHub organization ID."
  type        = string
}

variable "github_repo_id" {
  description = "Numeric GitHub repository ID."
  type        = string
}

variable "ecr_repository_name" {
  description = "ECR repository the deploy role may push to."
  type        = string
}
