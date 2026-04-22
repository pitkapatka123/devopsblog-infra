# -----------------------------------------------------------------------------
# S3 origin bucket for the static site.
#
# Access model: ONLY CloudFront (via Origin Access Control — OAC, not the
# legacy OAI) may GetObject. All public access blocked at the bucket level.
# Bucket policy further restricts access to the specific distribution ARN via
# aws:SourceArn. Versioning on (safe rollback of deploys), AES256 at rest.
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "origin" {
  bucket = var.origin_bucket_name

  # No `prevent_destroy`. The bucket's contents are fully reproducible via
  # `Application2/tooling/deploy.sh` (baker + aws s3 sync). Versioning +
  # the operator's deploy loop are sufficient; blocking destroy adds friction
  # without protecting anything irreplaceable. `prevent_destroy` is reserved
  # for the ACM cert and the Route 53 hosted zone, which ARE load-bearing
  # identities that cannot be recreated casually.

  tags = {
    Project   = "devopsblog"
    Component = "static-site-origin"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "origin" {
  bucket = aws_s3_bucket.origin.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "origin" {
  bucket = aws_s3_bucket.origin.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "origin" {
  bucket = aws_s3_bucket.origin.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "origin" {
  bucket = aws_s3_bucket.origin.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Bucket policy: allow CloudFront service principal to GetObject,
# but only when the request originates from our specific distribution
# (enforced via aws:SourceArn condition). This is the OAC pattern —
# access is scoped to the distribution ARN, not a CloudFront-wide principal.
data "aws_iam_policy_document" "origin" {
  statement {
    sid     = "AllowCloudFrontServicePrincipalReadOnly"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.origin.arn}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }

  # Belt-and-braces: deny ALL s3:* on this bucket (and its objects) if the
  # request was not made over TLS. CloudFront already uses TLS to reach S3
  # via OAC, so this is defence-in-depth rather than a blocker for any real
  # access path. Explicit Deny with NotPrincipal = * overrides the Allow above
  # ONLY when the transport is not TLS.
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.origin.arn,
      "${aws_s3_bucket.origin.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "origin" {
  bucket = aws_s3_bucket.origin.id
  policy = data.aws_iam_policy_document.origin.json

  # The bucket policy references the CloudFront distribution's ARN (OAC pattern).
  # The distribution in turn references the OAC (see cloudfront.tf); OAC does
  # NOT reference the bucket, so the circular dependency is broken at the OAC
  # boundary. We still need to ensure PAB is applied first so the policy doesn't
  # race with public-access-block semantics.
  depends_on = [aws_s3_bucket_public_access_block.origin]
}
