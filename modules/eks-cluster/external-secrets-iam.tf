############################################
# IAM for external-secrets (AWS Secrets Manager)
#
# Same pattern as the ALB controller and cert-manager: AWS-side IAM
# lives in Terraform, the actual operator install (Helm release) is
# ArgoCD's job, in gitops/infrastructure/<env>/.
#
# Scoped to Secrets Manager only (not SSM Parameter Store), and further
# scoped by name prefix via var.external_secrets_name_prefix. The
# default "*" allows all secrets in this account/region — narrow it
# (e.g. "eks-platform/dev/*") once you have a naming convention for
# secrets this cluster's workloads should be able to read.
############################################

data "aws_caller_identity" "eks_platform_current" {}
data "aws_region" "eks_platform_current" {}

data "aws_iam_policy_document" "eks_platform_external_secrets_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_platform_external_secrets" {
  name               = "${var.cluster_name}-external-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.eks_platform_external_secrets_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "eks_platform_external_secrets_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.eks_platform_current.name}:${data.aws_caller_identity.eks_platform_current.account_id}:secret:${var.external_secrets_name_prefix}"
    ]
  }

  # ListSecrets doesn't support resource-level restriction — required
  # for external-secrets' find-by-name/tag features, read-only.
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_platform_external_secrets" {
  name        = "${var.cluster_name}-external-secrets-policy"
  description = "Secrets Manager read permissions for external-secrets (${var.cluster_name})"
  policy      = data.aws_iam_policy_document.eks_platform_external_secrets_policy.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_platform_external_secrets" {
  role       = aws_iam_role.eks_platform_external_secrets.name
  policy_arn = aws_iam_policy.eks_platform_external_secrets.arn
}

resource "aws_eks_pod_identity_association" "eks_platform_external_secrets" {
  cluster_name    = aws_eks_cluster.eks_platform_cluster.name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.eks_platform_external_secrets.arn
  tags            = var.tags
}