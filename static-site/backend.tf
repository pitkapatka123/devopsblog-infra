terraform {
  backend "s3" {
    # State bucket lives in eu-west-1 (same bucket dev/ uses, different key).
    # Resources are deployed to eu-central-1 — cross-region backend is fine;
    # state storage region doesn't constrain resource region.
    bucket         = "tfstate-devopsblog2"
    key            = "static-site/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks-devopsblog2"
    encrypt        = true
  }
}
