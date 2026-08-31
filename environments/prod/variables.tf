variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 3
}

variable "nat_strategy" {
  type    = string
  default = "per_az"
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "endpoint_public_access" {
  description = "Whether the EKS public API endpoint is enabled. Best practice: false in prod, true (with CIDR restriction) acceptable in dev for convenience."
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  type    = list(string)
  default = [] # fill with your office/VPN CIDR(s) — never leave this as 0.0.0.0/0
}

variable "gitops_repo_url" {
  description = "Git URL of this repo, for ArgoCD's app-of-apps"
  type        = string
}

variable "gitops_target_revision" {
  type    = string
  default = "main"
}

variable "tags" {
  type = map(string)
  default = {
    ManagedBy = "terraform"
  }
}