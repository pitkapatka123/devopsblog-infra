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

  # Origin bucket holds the deployed site artifact. Accidental destroy would
  # break the site and require a fresh baker run + deploy.
  lifecycle {
    prevent_destroy = true
  }

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
