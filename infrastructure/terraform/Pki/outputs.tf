output "ca_kms_key_arn" {
  description = "ARN of the CMK protecting the issuing CA key material."
  value       = aws_kms_key.ca.arn
}

output "ca_kms_key_alias" {
  description = "Alias of the CA CMK."
  value       = aws_kms_alias.ca.name
}

output "ca_host_id" {
  description = "Instance ID of the CA host (null when create_ca_host is false)."
  value       = try(aws_instance.ca_host[0].id, null)
}

output "ca_host_role_name" {
  description = "IAM role attached to the CA host (null when create_ca_host is false)."
  value       = try(aws_iam_role.ca_host[0].name, null)
}
