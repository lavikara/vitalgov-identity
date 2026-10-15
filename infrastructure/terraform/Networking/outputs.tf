output "vpc_id" {
  description = "ID of the VitalGov VPC."
  value       = aws_vpc.vitalgov.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.vitalgov.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB + NAT)."
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "Private application subnet IDs."
  value       = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  description = "Private data subnet IDs."
  value       = aws_subnet.data[*].id
}

output "pki_subnet_ids" {
  description = "Restricted PKI subnet IDs."
  value       = aws_subnet.pki[*].id
}

output "app_route_table_ids" {
  description = "Route table IDs of the application subnets (S3 gateway endpoint attaches here)."
  value       = aws_route_table.app[*].id
}

output "data_route_table_ids" {
  description = "Route table IDs of the data subnets (S3 gateway endpoint attaches here)."
  value       = aws_route_table.data[*].id
}

output "pki_route_table_ids" {
  description = "Route table IDs of the PKI subnets (S3 gateway endpoint attaches here)."
  value       = aws_route_table.pki[*].id
}

output "nat_gateway_id" {
  description = "ID of the shared NAT gateway."
  value       = aws_nat_gateway.main.id
}

output "flow_logs_log_group_name" {
  description = "CloudWatch log group receiving VPC flow logs."
  value       = aws_cloudwatch_log_group.flow_logs.name
}
