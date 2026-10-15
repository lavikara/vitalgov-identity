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
  description = "AWS region where the ops host runs."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to ops resources."
  type        = map(string)
  default     = {}
}

variable "app_subnet_ids" {
  description = "Private application subnet IDs for the ops host."
  type        = list(string)
}

variable "ops_security_group_id" {
  description = "Security group for the ops host (owned by the SecurityGroups module)."
  type        = string
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key (SecureString parameter). Empty until rotation completes (I-023); Parameter Store rejects empty values."
  type        = string
  default     = "pending-I-023"
  sensitive   = true
}

variable "wazuh_manager_ip" {
  description = "Wazuh manager address (tailnet IP or hostname). Empty until the manager is reachable (I-024); Parameter Store rejects empty values."
  type        = string
  default     = "unset"
}
