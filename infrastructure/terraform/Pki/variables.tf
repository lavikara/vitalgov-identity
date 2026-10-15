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
  description = "Common tags applied to PKI resources."
  type        = map(string)
  default     = {}
}

variable "pki_subnet_ids" {
  description = "Restricted PKI subnet IDs for the CA host."
  type        = list(string)
}

variable "ca_security_group_id" {
  description = "Security group for the CA host (owned by the SecurityGroups module)."
  type        = string
}

variable "create_ca_host" {
  description = "Create the placeholder CA host. Keep false until the I-007 CA software decision; the CMK is created either way."
  type        = bool
  default     = false
}

variable "deploy_role_arn" {
  description = "ARN of the GitHub Actions deploy role, passed (not interpolated) so the KMS key policy has a real dependency edge on module.iam."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the CA host."
  type        = string
  default     = "t3.micro"
}
