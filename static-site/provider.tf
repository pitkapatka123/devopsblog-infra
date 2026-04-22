terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Pinned per .claude/rules/infra.md "Version pinning" — no floating ~>.
      # Resolved version matches Infra/dev/.terraform.lock.hcl (6.28.0).
      version = "6.28.0"
    }
  }
}

# Default regional provider: all workload resources (S3 origin, CloudFront
# distribution, Route 53 records) target eu-central-1 to align with prod.
# Note: CloudFront and Route 53 are global services; specifying a region for
# their resources has no effect beyond where the API calls are made.
provider "aws" {
  region = var.aws_region
}

# Aliased provider for us-east-1.
# REQUIRED for the ACM certificate consumed by CloudFront: AWS hardcodes the
# CloudFront service to look up viewer certificates in us-east-1 only.
# Any cert attached to a CloudFront distribution MUST live in us-east-1,
# regardless of where the rest of the stack runs. The ACM certificate and
# its DNS validation record creation use this alias.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

variable "aws_region" {
  description = "Default AWS region for regional resources (S3 origin bucket)."
  type        = string
  default     = "eu-central-1"
}

variable "site_domain" {
  description = "Apex domain served by the static site."
  type        = string
  default     = "devopsblog.online"
}

variable "site_www_domain" {
  description = "www subdomain (added as SAN on the cert and as an ALIAS A record)."
  type        = string
  default     = "www.devopsblog.online"
}

variable "origin_bucket_name" {
  description = "S3 origin bucket name. Stable / predictable; change only if the global namespace conflict forces it."
  type        = string
  default     = "devopsblog-site-origin"
}
