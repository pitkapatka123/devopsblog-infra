output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = local.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint URL of the EKS cluster Kubernetes API"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster (for IRSA)"
  value       = module.eks.oidc_provider_arn
}

output "eks_cluster_iam_role_arn" {
  description = "ARN of the IAM role used by the EKS control plane"
  value       = module.eks.cluster_iam_role_arn
}

output "eks_node_group_iam_role_arn" {
  description = "ARN of the IAM role used by the EKS worker node group"
  value       = module.eks.eks_managed_node_groups["workers"].iam_role_arn
}

output "vpc_id" {
  description = "ID of the VPC created for EKS"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets in the VPC"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets in the VPC"
  value       = module.vpc.private_subnets
}
