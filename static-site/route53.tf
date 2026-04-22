# -----------------------------------------------------------------------------
# Route 53 hosted zone for devopsblog.online + DNS records.
#
# Zone is fresh (no import). After `terraform apply` the operator must point
# GoDaddy's NS for devopsblog.online at the four nameservers exposed via the
# route53_nameservers output. Allow 5-60 min for propagation before `deploy.sh`
# is useful.
# -----------------------------------------------------------------------------

resource "aws_route53_zone" "site" {
  name    = var.site_domain
  comment = "Hosted zone for devopsblog.online static site"

  # Destroying the zone invalidates all DNS records and cycles the NS set,
  # forcing a second registrar update and DNS propagation wait. Protect it.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project   = "devopsblog"
    Component = "static-site-dns"
    ManagedBy = "terraform"
  }
}

# ACM DNS-validation records. One record per domain in the cert (apex + www).
# The cert is created in us-east-1 (acm.tf) but Route 53 is global — records
# live in the zone via the default provider.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = aws_route53_zone.site.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# Apex ALIAS -> CloudFront
resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.site.zone_id
  name    = var.site_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# www ALIAS -> CloudFront (same distribution; both aliases are in `aliases`
# on the distribution so a single distribution serves both hostnames).
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.site.zone_id
  name    = var.site_www_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# CAA record on the apex.
# - `issue "amazon.com"` — only Amazon's CA (ACM) may issue non-wildcard certs.
# - `issuewild ";"` — no CA may issue wildcard certs for this domain.
# - `iodef "mailto:..."` — contact for policy-violation reports. Uses a
#   generic placeholder; operator can update later without an infra rebuild.
resource "aws_route53_record" "caa" {
  zone_id = aws_route53_zone.site.zone_id
  name    = var.site_domain
  type    = "CAA"
  ttl     = 300

  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \";\"",
    "0 iodef \"mailto:admin@devopsblog.online\"",
  ]
}
