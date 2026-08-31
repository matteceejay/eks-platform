resource "kubernetes_namespace" "eks_platform_argocd" {
  metadata {
    name   = var.argocd_namespace
    labels = var.tags
  }
}

resource "helm_release" "eks_platform_argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.eks_platform_argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  # Baseline hardening: disable the insecure flag off (TLS stays on
  # inside the cluster), require login over HTTPS at the ingress layer
  # you add later. Anything in var.argocd_values overrides/extends this.
  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = false
        }
      }
    }),
    var.argocd_values
  ]

  depends_on = [kubernetes_namespace.eks_platform_argocd]
}

# The app-of-apps: a single ArgoCD Application pointing at the gitops/
# repo path. Every add-on/tool from here forward is a Git commit under
# that path, not a Terraform resource. This is the last Kubernetes
# object Terraform ever creates directly.
#
# Using the kubectl provider (not kubernetes_manifest) here deliberately:
# kubernetes_manifest validates the CRD schema against the live API
# server at plan time, which fails on the very first apply before the
# Application CRD exists (installed moments earlier by the Helm release
# above). kubectl_manifest applies without that plan-time CRD lookup.
resource "kubectl_manifest" "eks_platform_app_of_apps" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps"
      namespace = kubernetes_namespace.eks_platform_argocd.metadata[0].name
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        path           = var.gitops_repo_path
        targetRevision = var.gitops_target_revision
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  })

  depends_on = [helm_release.eks_platform_argocd]
}