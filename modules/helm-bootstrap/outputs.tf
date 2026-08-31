output "argocd_namespace" {
  value = kubernetes_namespace.eks_platform_argocd.metadata[0].name
}

output "argocd_release_name" {
  value = helm_release.eks_platform_argocd.name
}