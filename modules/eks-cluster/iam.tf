# modules/eks-cluster/iam.tf
############################################
# Cluster IAM role (Auto Mode)
############################################

data "aws_iam_policy_document" "eks_platform_cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_platform_cluster_role" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_platform_cluster_assume_role.json
  tags               = var.tags
}

# Required managed policies for EKS Auto Mode (storage, networking, load
# balancing, and compute are all handled by the cluster role, not the
# node role, under Auto Mode).
resource "aws_iam_role_policy_attachment" "eks_platform_cluster_role_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSComputePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy",
  ])

  role       = aws_iam_role.eks_platform_cluster_role.name
  policy_arn = each.value
}

############################################
# Node IAM role (Auto Mode nodes)
############################################

data "aws_iam_policy_document" "eks_platform_node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_platform_node_role" {
  name               = "${var.cluster_name}-auto-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_platform_node_assume_role.json
  tags               = var.tags
}

# Auto Mode nodes use the minimal policy (a trimmed-down successor to
# AmazonEKSWorkerNodePolicy) plus pull-only ECR access. Do not
# substitute the older AmazonEKSWorkerNodePolicy / ReadOnly policies —
# those grant broader permissions than Auto Mode nodes need.
resource "aws_iam_role_policy_attachment" "eks_platform_node_role_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
  ])

  role       = aws_iam_role.eks_platform_node_role.name
  policy_arn = each.value
}