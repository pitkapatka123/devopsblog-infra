# -----------------------------------------------------------------------------
# Outputs — contract with Application2/tooling/deploy.sh.
# Output NAMES are load-bearing; do not rename without coordinating with the
# backend-engineer owning deploy.sh.
# -----------------------------------------------------------------------------

output "s3_bucket_name" {
  description = "Name of the S3 origin bucket (consumed by deploy.sh for `aws s3 sync`)."
  value       = aws_s3_bucket.origin.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (consumed by deploy.sh for `aws cloudfront create-invalidation`)."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain (*.cloudfront.net). For debugging / direct access before DNS is switched."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "route53_nameservers" {
  description = "Four Route 53 nameservers for the hosted zone. Operator pastes these into GoDaddy's NS records for devopsblog.online."
  value       = aws_route53_zone.site.name_servers
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate in us-east-1 attached to the CloudFront distribution."
  value       = aws_acm_certificate.site.arn
}
