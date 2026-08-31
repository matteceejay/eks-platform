provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      Environment = var.environment
    })
  }
}

# These three providers all authenticate against the cluster this same
# config creates. IMPORTANT: on the very first apply for a brand-new
# cluster, run this as two separate applies, not one:
#   1) terraform apply -target=module.eks_platform_cluster
#   2) terraform apply
# Provider configuration blocks are evaluated before Terraform's graph
# walk fully resolves resource attributes, so a single apply that both
# creates the cluster AND tries to use these providers in the same run
# can fail with "Kubernetes cluster unreachable: invalid configuration."
# Once the cluster exists in state, subsequent applies (adding/changing
# other resources) work fine as a single `terraform apply` — this only
# affects first-time creation.
#
# Auth method: exec-based, not the static aws_eks_cluster_auth data
# source. The static token is only valid 15 minutes; if there's any
# delay between Terraform evaluating it and actually applying Kubernetes
# resources (reviewing a plan, EKS taking time to settle, retries), the
# token can go stale mid-apply and produce "Unauthorized." The exec
# method runs `aws eks get-token` fresh at the moment each provider
# actually needs to authenticate, avoiding that entirely — this is the
# method the Kubernetes/Helm providers' own docs recommend for EKS.
# Requires the AWS CLI (v2) to be installed and on PATH.

provider "kubernetes" {
  host                   = module.eks_platform_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_platform_cluster.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_platform_cluster.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks_platform_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_platform_cluster.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_platform_cluster.cluster_name, "--region", var.aws_region]
    }
  }
}

provider "kubectl" {
  host                   = module.eks_platform_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_platform_cluster.cluster_certificate_authority_data)
  load_config_file       = false
  apply_retry_count      = 5

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_platform_cluster.cluster_name, "--region", var.aws_region]
  }
}