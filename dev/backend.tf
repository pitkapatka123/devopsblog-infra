terraform {
  backend "s3" {
    bucket         = "tfstate-devopsblog"
    key            = "dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "devopsblog-terraform-locks"
    encrypt        = true
  }
}