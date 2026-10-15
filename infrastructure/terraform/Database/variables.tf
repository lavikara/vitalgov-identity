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
  description = "Common tags applied to database resources."
  type        = map(string)
  default     = {}
}

variable "data_subnet_ids" {
  description = "Private data subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "Security group for the RDS instance (owned by the SecurityGroups module)."
  type        = string
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL master password."
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "monitoring_interval" {
  description = "RDS enhanced monitoring interval in seconds. 0 disables it."
  type        = number
  default     = 60
}

variable "backup_retention_period" {
  description = "Automated backup retention in days (open decision I-011)."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection on the DB instance."
  type        = bool
  default     = false
}
