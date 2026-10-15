data "aws_region" "current" {}

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
  description = "Common tags applied to VPC endpoints."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC where the endpoints are created."
  type        = string
}

variable "app_subnet_ids" {
  description = "Private application subnet IDs hosting the interface endpoints."
  type        = list(string)
}

variable "app_route_table_ids" {
  description = "Application route tables receiving the S3 gateway endpoint."
  type        = list(string)
}

variable "data_route_table_ids" {
  description = "Data route tables receiving the S3 gateway endpoint."
  type        = list(string)
}

variable "pki_route_table_ids" {
  description = "PKI route tables receiving the S3 gateway endpoint (CA tier artifact access)."
  type        = list(string)
  default     = []
}

variable "endpoints_security_group_id" {
  description = "Security group attached to the interface endpoints."
  type        = string
}

variable "endpoint_az_count" {
  description = "Number of AZs hosting interface endpoints. 1 matches the single-NAT cost trade-off (ADR-010)."
  type        = number
  default     = 1

  validation {
    condition     = var.endpoint_az_count >= 1 && var.endpoint_az_count <= 2
    error_message = "endpoint_az_count must be 1 or 2."
  }
}
