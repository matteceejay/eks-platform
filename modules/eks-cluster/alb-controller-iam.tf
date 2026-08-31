############################################
# IAM for the AWS Load Balancer Controller
#
# This is AWS-side IAM, not a Kubernetes workload — it belongs in
# Terraform even though the controller itself (the Helm release) is
# installed by ArgoCD from gitops/infrastructure/<env>/. Uses EKS Pod
# Identity (not IRSA) — Auto Mode already runs the Pod Identity Agent,
# no separate addon needed.
#
# The Helm chart's ServiceAccount name (aws-load-balancer-controller,
# in kube-system) must exactly match what's associated below. Unlike
# IRSA, Pod Identity does NOT need serviceAccount.create=false or an
# eks.amazonaws.com/role-arn annotation — the chart can create the
# ServiceAccount normally (Helm's default), and the EKS Pod Identity
# webhook attaches credentials by matching name+namespace at pod
# admission time.
############################################

data "aws_iam_policy_document" "eks_platform_alb_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_platform_alb_controller" {
  name               = "${var.cluster_name}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.eks_platform_alb_controller_assume_role.json
  tags               = var.tags
}

# Official policy from kubernetes-sigs/aws-load-balancer-controller
# (docs/install/iam_policy.json, main branch, saved verbatim in
# policies/alb-controller-iam-policy.json) — do not hand-trim this;
# missing actions surface as opaque reconcile failures in the
# controller's logs, not as an obvious Terraform-side error.
resource "aws_iam_policy" "eks_platform_alb_controller" {
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "Permissions for the AWS Load Balancer Controller (${var.cluster_name})"
  policy      = file("${path.module}/policies/alb-controller-iam-policy.json")
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_platform_alb_controller" {
  role       = aws_iam_role.eks_platform_alb_controller.name
  policy_arn = aws_iam_policy.eks_platform_alb_controller.arn
}

resource "aws_eks_pod_identity_association" "eks_platform_alb_controller" {
  cluster_name    = aws_eks_cluster.eks_platform_cluster.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.eks_platform_alb_controller.arn
  tags            = var.tags
}