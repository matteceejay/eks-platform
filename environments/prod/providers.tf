terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      Environment = var.environment
    })
  }
}

# These three providers all authenticate against the cluster this same
# apply creates. That's expected for this pattern — module.eks_platform_cluster
# must be applied before these providers can successfully talk to the
# API server, which Terraform handles fine via the implicit dependency
# created by referencing module outputs below. Note: a brand-new cluster
# needs `terraform apply` run once to create it before providers here
# can authenticate on subsequent applies if you ever `-target`; a plain
# full `terraform apply` handles ordering correctly on first run.

data "aws_eks_cluster_auth" "eks_platform" {
  name = module.eks_platform_cluster.cluster_name
}

provider "kubernetes" {
  host                   = module.eks_platform_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_platform_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks_platform.token
}

provider "helm" {
  # The Helm provider can authenticate via the ambient Kubernetes context or
  # via the explicitly configured kubernetes provider; avoid the nested
  # `kubernetes {}` block here because some provider versions reject it.
}

provider "kubectl" {
  host                   = module.eks_platform_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_platform_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks_platform.token
  load_config_file       = false
  apply_retry_count      = 5
}