# -----------------------------------------------------------------------------
# ACM certificate for the site.
#
# MUST be in us-east-1 — CloudFront only reads viewer certificates from that
# region, regardless of where the rest of the stack runs. Hence provider =
# aws.us_east_1 here. The Route 53 hosted zone is global, so validation records
# are created in the default provider's Route 53 (route53.tf).
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "site" {
  provider = aws.us_east_1

  domain_name               = var.site_domain
  subject_alternative_names = [var.site_www_domain]
  validation_method         = "DNS"

  # Long-lived identity backing CloudFront; replacement causes downtime.
  # `create_before_destroy` deliberately OMITTED: it contradicts `prevent_destroy`
  # (replace-then-drop vs. block-drop). Pass 1 audit flagged the pairing as
  # mutually incoherent. Keep `prevent_destroy` — the cert is the load-bearing
  # identity for the distribution and must not be recreated casually.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project   = "devopsblog"
    Component = "static-site-cert"
    ManagedBy = "terraform"
  }
}

# DNS validation records live in the Route 53 hosted zone (default provider —
# Route 53 is global). See route53.tf for aws_route53_record.cert_validation.

resource "aws_acm_certificate_validation" "site" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
