locals {
  cluster_name = "eks-platform-${var.environment}"

  common_tags = merge(var.tags, {
    Environment = var.environment
    Cluster     = local.cluster_name
  })
}

module "eks_platform_vpc" {
  source = "../../modules/vpc"

  name         = local.cluster_name
  vpc_cidr     = var.vpc_cidr
  az_count     = var.az_count
  nat_strategy = var.nat_strategy
  cluster_name = local.cluster_name
  tags         = local.common_tags
}

module "eks_platform_cluster" {
  source = "../../modules/eks-cluster"

  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.eks_platform_vpc.vpc_id
  subnet_ids          = module.eks_platform_vpc.private_subnet_ids

  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  route53_hosted_zone_id = var.route53_hosted_zone_id

  tags = local.common_tags
}

module "eks_platform_helm_bootstrap" {
  source = "../../modules/helm-bootstrap"

  gitops_repo_url        = var.gitops_repo_url
  gitops_repo_path       = "gitops/infrastructure/${var.environment}"
  gitops_target_revision = var.gitops_target_revision

  tags = local.common_tags

  depends_on = [module.eks_platform_cluster]
}