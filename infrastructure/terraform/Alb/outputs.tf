output "alb_id" {
  description = "ID of the Application Load Balancer."
  value       = aws_lb.application.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.application.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.application.dns_name
}

output "alb_zone_id" {
  description = "Route53-compatible hosted zone ID of the Application Load Balancer."
  value       = aws_lb.application.zone_id
}

output "target_group_arn" {
  description = "ARN of the ALB target group."
  value       = aws_lb_target_group.application.arn
}

output "target_group_id" {
  description = "ID of the ALB target group."
  value       = aws_lb_target_group.application.id
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener."
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener, if enabled."
  value       = try(aws_lb_listener.https[0].arn, null)
}
