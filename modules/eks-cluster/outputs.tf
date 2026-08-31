output "cluster_name" {
  value = aws_eks_cluster.eks_platform_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks_platform_cluster.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.eks_platform_cluster.certificate_authority[0].data
}

output "cluster_arn" {
  value = aws_eks_cluster.eks_platform_cluster.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks_platform_oidc.arn
}

output "oidc_provider_url" {
  value = replace(aws_eks_cluster.eks_platform_cluster.identity[0].oidc[0].issuer, "https://", "")
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.eks_platform_cluster.vpc_config[0].cluster_security_group_id
}

output "node_role_arn" {
  value = aws_iam_role.eks_platform_node_role.arn
}