output "db_instance_id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.vitalgov.id
}

output "db_endpoint" {
  description = "RDS endpoint including the port (host:5432)."
  value       = aws_db_instance.vitalgov.endpoint
}

output "db_hostname" {
  description = "RDS hostname only (no port), for Keycloak KC_DB_URL_HOST and similar."
  value       = aws_db_instance.vitalgov.address
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.vitalgov.name
}
