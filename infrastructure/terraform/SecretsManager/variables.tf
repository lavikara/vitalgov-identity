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
  description = "Common tags applied to secrets."
  type        = map(string)
  default     = {}
}

variable "db_host" {
  description = "RDS endpoint (host:port) stored for consumers."
  type        = string
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
}

variable "db_user" {
  description = "PostgreSQL username."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL password."
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret."
  type        = string
  sensitive   = true
}

variable "keycloak_admin_password" {
  description = "Keycloak bootstrap admin password."
  type        = string
  sensitive   = true
}
