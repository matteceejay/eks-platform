variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "nat_strategy" {
  type    = string
  default = "single"
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "endpoint_public_access" {
  description = "Dev convenience: public endpoint on, restricted to office/VPN CIDRs. Set false and use a bastion/VPN for prod."
  type        = bool
  default     = true
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

variable "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID for cert-manager DNS-01 challenges"
  type        = string
  default     = ""
}