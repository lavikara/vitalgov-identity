output "instance_ids" {
  description = "Map of ops host role → EC2 instance ID."
  value       = { ops = aws_instance.ops.id }
}

output "instance_private_ips" {
  description = "Map of ops host role → private IP."
  value       = { ops = aws_instance.ops.private_ip }
}

output "tailscale_auth_key_parameter" {
  description = "SSM parameter holding the Tailscale auth key."
  value       = aws_ssm_parameter.tailscale_auth_key.name
}
