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
  description = "Common tags applied to networking resources."
  type        = map(string)
  default     = {}
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

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (ALB + NAT placement)."
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "Private application subnet CIDRs."
  type        = list(string)
}

variable "data_subnet_cidrs" {
  description = "Private data subnet CIDRs (no internet route)."
  type        = list(string)
}

variable "pki_subnet_cidrs" {
  description = "Restricted PKI/CA subnet CIDRs (no internet route)."
  type        = list(string)
}

variable "log_retention_days" {
  description = "CloudWatch log retention for flow logs."
  type        = number
  default     = 90
}
