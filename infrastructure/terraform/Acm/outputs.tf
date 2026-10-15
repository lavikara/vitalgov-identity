output "certificate_arn" {
  description = "ARN of the ACM certificate."
  value       = aws_acm_certificate.main.arn
}

output "domain_name" {
  description = "Domain name of the certificate."
  value       = aws_acm_certificate.main.domain_name
}

output "validation_record" {
  description = "CNAME to create at the external DNS provider for validation."
  value = {
    for dvo in aws_acm_certificate.main.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
    }
  }
}
