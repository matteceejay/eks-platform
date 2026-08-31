# modules/eks-cluster/main.tf
############################################
# KMS key for envelope-encrypting Kubernetes Secrets
############################################

resource "aws_kms_key" "eks_platform_secrets" {
  description             = "Envelope encryption for ${var.cluster_name} Kubernetes secrets"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = var.tags
}

resource "aws_kms_alias" "eks_platform_secrets" {
  name          = "alias/${var.cluster_name}-eks-secrets"
  target_key_id = aws_kms_key.eks_platform_secrets.key_id
}

############################################
# EKS Cluster (Auto Mode, bare — no ArgoCD/add-ons here)
# IAM roles for this cluster live in iam.tf
############################################

resource "aws_eks_cluster" "eks_platform_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_platform_cluster_role.arn
  version  = var.kubernetes_version

  # Auto Mode requires the newer API access-entry authentication mode.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Must be false for Auto Mode — Auto Mode manages CoreDNS, kube-proxy,
  # and VPC CNI itself; letting Terraform also bootstrap them causes
  # conflicting ownership and recreation loops.
  bootstrap_self_managed_addons = false

  # the 

  compute_config {
    enabled       = true
    node_pools    = var.auto_mode_node_pools
    node_role_arn = aws_iam_role.eks_platform_node_role.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.endpoint_public_access_cidrs : null
  }

  # Envelope encryption for Secrets — not on by default, must be set at
  # creation time; cannot be added retroactively without a new cluster.
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_platform_secrets.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_platform_cluster_role_policies,
    aws_iam_role_policy_attachment.eks_platform_node_role_policies,
  ]
}

############################################
# OIDC provider — kept for workloads/tools that still expect IRSA
# (Pod Identity is preferred for new workloads, see helm-bootstrap module)
############################################

data "tls_certificate" "eks_platform_oidc" {
  url = aws_eks_cluster.eks_platform_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_platform_oidc" {
  url             = aws_eks_cluster.eks_platform_cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_platform_oidc.certificates[0].sha1_fingerprint]
  tags            = var.tags
}