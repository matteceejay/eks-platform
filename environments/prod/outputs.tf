output "cluster_name" {
  value = module.eks_platform_cluster.cluster_name
}

output "cluster_endpoint" {
  value = module.eks_platform_cluster.cluster_endpoint
}

output "vpc_id" {
  value = module.eks_platform_vpc.vpc_id
}

output "argocd_namespace" {
  value = module.eks_platform_helm_bootstrap.argocd_namespace
}

output "configure_kubeconfig" {
  value       = "aws eks update-kubeconfig --name ${module.eks_platform_cluster.cluster_name} --region ${var.aws_region}"
  description = "Run this to point kubectl at the new cluster"
}