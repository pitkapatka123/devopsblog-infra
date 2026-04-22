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
  }

  # Belt-and-braces: map 404s to Frozen-Flask's /404.html (the baker is expected
  # to produce this; if it doesn't, CloudFront still returns a 404 without the
  # custom body).
  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

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
