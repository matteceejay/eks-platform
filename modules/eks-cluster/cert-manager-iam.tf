############################################
# IAM for cert-manager (Route53 DNS-01 challenges)
#
# Same pattern as the ALB controller: AWS-side IAM lives in Terraform,
# the actual cert-manager install (Helm release) and ClusterIssuer
# objects are ArgoCD's job, in gitops/infrastructure/<env>/.
#
# Scoped to a single hosted zone via var.route53_hosted_zone_id — this
# role can only write records in that zone, not any Route53 zone in the
# account. route53:ListHostedZonesByName is left account-wide because
# that specific action doesn't support resource-level restriction, but
# it's read-only and low-risk.
############################################

data "aws_iam_policy_document" "eks_platform_cert_manager_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_platform_cert_manager" {
  name               = "${var.cluster_name}-cert-manager-role"
  assume_role_policy = data.aws_iam_policy_document.eks_platform_cert_manager_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "eks_platform_cert_manager_route53" {
  statement {
    effect    = "Allow"
    actions   = ["route53:GetChange"]
    resources = ["arn:aws:route53:::change/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
    resources = ["arn:aws:route53:::hostedzone/${var.route53_hosted_zone_id}"]
  }

  statement {
    effect    = "Allow"
    actions   = ["route53:ListHostedZonesByName"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_platform_cert_manager" {
  name        = "${var.cluster_name}-cert-manager-policy"
  description = "Route53 DNS-01 permissions for cert-manager (${var.cluster_name}), scoped to one hosted zone"
  policy      = data.aws_iam_policy_document.eks_platform_cert_manager_route53.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_platform_cert_manager" {
  role       = aws_iam_role.eks_platform_cert_manager.name
  policy_arn = aws_iam_policy.eks_platform_cert_manager.arn
}

resource "aws_eks_pod_identity_association" "eks_platform_cert_manager" {
  cluster_name    = aws_eks_cluster.eks_platform_cluster.name
  namespace       = "cert-manager"
  service_account = "cert-manager"
  role_arn        = aws_iam_role.eks_platform_cert_manager.arn
  tags            = var.tags
}