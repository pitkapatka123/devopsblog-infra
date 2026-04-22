# -----------------------------------------------------------------------------
# CloudFront distribution + Origin Access Control.
#
# OAC (not the legacy OAI) is the current AWS-recommended pattern. The OAC is
# attached to the origin and signs requests to S3 using SigV4. The S3 bucket
# policy (s3.tf) restricts s3:GetObject to this distribution's ARN.
# -----------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "devopsblog-site-oac"
  description                       = "OAC for devopsblog static site S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# -----------------------------------------------------------------------------
# Response-headers policy.
#
# A custom policy (not the AWS-managed SecurityHeadersPolicy) is used because
# the site loads Google Fonts (fonts.googleapis.com / fonts.gstatic.com) and
# has some inline styles — the managed policy's default CSP is stricter than
# what the app actually needs, so a custom CSP is the pragmatic choice.
#
# Wired into default_cache_behavior.response_headers_policy_id below.
# -----------------------------------------------------------------------------
resource "aws_cloudfront_response_headers_policy" "site" {
  name    = "devopsblog-site-security-headers"
  comment = "Security headers for devopsblog static site (HSTS, CSP, XFO, etc.)"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000 # 2 years
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    content_security_policy {
      content_security_policy = "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; script-src 'self'"
      override                = true
    }
  }
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "devopsblog static site"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # US + Europe only — cheapest
  http_version        = "http2"          # explicit per spec
  aliases             = [var.site_domain, var.site_www_domain]

  origin {
    domain_name              = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id                = "s3-devopsblog-site-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-devopsblog-site-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS-managed CachingOptimized policy
    # (https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html)
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    # Custom security-headers policy (see aws_cloudfront_response_headers_policy.site above).
    response_headers_policy_id = aws_cloudfront_response_headers_policy.site.id
  }

  # NOTE: No `custom_error_response` block. Frozen-Flask does not generate a
  # /404.html, so mapping CloudFront 404s to that path would loop on a missing
  # error page. For a first-ship, S3's native 403 on missing-object-via-OAC is
  # acceptable — operator can add a branded 404 later via a Flask route that
  # bakes to /404.html. See README.md for the deferred-work note.

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.site.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Do NOT attempt to serve traffic until ACM validation has completed; otherwise
  # the distribution creation races the cert and fails with InvalidViewerCertificate.
  depends_on = [aws_acm_certificate_validation.site]

  tags = {
    Project   = "devopsblog"
    Component = "static-site-cdn"
    ManagedBy = "terraform"
  }

  # Logging left OFF intentionally (adds S3 cost). Spec: can be added later.
}
