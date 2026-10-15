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
  description = "Common tags applied to security groups."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC where the security groups are created."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR used for DNS egress rules to the VPC resolver."
  type        = string
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the ALB (clinic networks; narrow at deployment)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "clinic_federation_cidrs" {
  description = "Registry-scoped CIDRs for clinic federation egress (F10–F14). Narrow from 0.0.0.0/0 at deployment per §5.1."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_target_port" {
  description = "Port the ALB forwards to (API in wave 1, gateway once deployed)."
  type        = number
  default     = 3000
}

variable "gateway_admin_port" {
  description = "Gateway admin/API port (ops tier only)."
  type        = number
  default     = 9180
}

variable "api_port" {
  description = "Application API port."
  type        = number
  default     = 3000
}

variable "keycloak_port" {
  description = "Keycloak identity port."
  type        = number
  default     = 8080
}

variable "ca_port" {
  description = "CA/OCSP service port (follows the I-007 decision)."
  type        = number
  default     = 8551
}
