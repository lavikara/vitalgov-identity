output "s3_gateway_endpoint_id" {
  description = "ID of the S3 gateway endpoint."
  value       = aws_vpc_endpoint.s3.id
}

output "interface_endpoint_ids" {
  description = "Map of interface endpoint name → VPC endpoint ID."
  value       = { for k, ep in aws_vpc_endpoint.interface : k => ep.id }
}
