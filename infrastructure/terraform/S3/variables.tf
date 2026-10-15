variable "project_name" {
  description = "Name of the application/project."
  type        = string
  default     = "vitalgov"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "production"
}

variable "bucket_purpose" {
  description = "Suffix identifying the bucket's purpose, e.g. realm-backups."
  type        = string
  default     = "realm-backups"
}

variable "common_tags" {
  description = "Common tags applied to the bucket."
  type        = map(string)
  default     = {}
}
