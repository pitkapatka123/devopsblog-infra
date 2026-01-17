module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 6.0.0"

  name = local.vpc_name
  cidr = local.vpc_cidr
  azs  = local.azs

  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  map_public_ip_on_launch = true
  enable_nat_gateway      = true
  single_nat_gateway      = true
  one_nat_gateway_per_az  = false

  enable_dns_hostnames = true
  enable_dns_support   = true
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.10.1"


  name               = local.cluster_name
  kubernetes_version = "1.30"

  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  enable_cluster_creator_admin_permissions = true
  addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }
  enabled_log_types = ["api", "audit", "scheduler"]


  endpoint_public_access  = true
  endpoint_private_access = true


  eks_managed_node_groups = {
    workers = {
      name           = local.nodegroup_name
      instance_types = ["t3.medium"]

      desired_size = 2
      min_size     = 1
      max_size     = 3

      subnet_ids = module.vpc.private_subnets
    }
  }
  security_group_additional_rules = {
    ingress_nodes_443 = {
      description                = "hanging connection potential fix"
      protocol                   = "tcp"
      from_port                  = 443
      to_port                    = 443
      type                       = "ingress"
      source_node_security_group = true
    }
  }
}

