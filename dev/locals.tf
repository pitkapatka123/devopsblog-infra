locals {
  vpc_name       = "devopsblog-dev-vpc"
  cluster_name   = "devopsblog-dev-cluster"
  nodegroup_name = "devopsblog-dev-workers"

  vpc_cidr = "10.0.0.0/16"

  azs = ["eu-central-1a", "eu-central-1b"]

  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
}
variable "aws_region" {
  description = "aws region i use"
  type        = string
  default     = "eu-central-1"
}
