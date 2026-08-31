variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version (from https://artifacthub.io/packages/helm/argo/argo-cd) — pin explicitly, do not float on latest"
  type        = string
  default     = "10.4.1"
}

variable "argocd_values" {
  description = "Raw Helm values YAML for the argo-cd chart, merged over the module's baseline values"
  type        = string
  default     = ""
}

variable "gitops_repo_url" {
  description = "Git repo URL that ArgoCD's app-of-apps Application will point at (the gitops/ directory of this repo)"
  type        = string
}

variable "gitops_repo_path" {
  description = "Path within gitops_repo_url for the root app-of-apps (e.g. gitops/infrastructure)"
  type        = string
  default     = "gitops/infrastructure"
}

variable "gitops_target_revision" {
  description = "Git branch/tag ArgoCD tracks for the app-of-apps"
  type        = string
  default     = "main"
}

variable "tags" {
  type    = map(string)
  default = {}
}