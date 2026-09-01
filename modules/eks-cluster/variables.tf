variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the control plane"
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  description = "VPC ID (from the vpc module)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the cluster control plane ENIs and Auto Mode nodes (private subnets recommended)"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Whether the EKS public API endpoint is enabled. Best practice: false in prod, true (with CIDR restriction) acceptable in dev for convenience."
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint, only relevant if endpoint_public_access = true"
  type        = list(string)
  default     = []
}

variable "auto_mode_node_pools" {
  description = "EKS Auto Mode built-in node pools to enable"
  type        = list(string)
  default     = ["system", "general-purpose"]
}

variable "enabled_cluster_log_types" {
  description = "Control plane log types shipped to CloudWatch"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}


variable "external_secrets_name_prefix" {
  description = "Secrets Manager secret name prefix external-secrets is allowed to read (e.g. \"eks-platform/*\"). Default \"*\" allows all secrets in the account/region — narrow this once you know your naming convention."
  type        = string
  default     = "*"
}



variable "tags" {
  type    = map(string)
  default = {}
}

variable "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID cert-manager is scoped to for DNS-01 challenges (e.g. Z0123456789ABCDEFGHIJ)"
  type        = string
  default     = ""
}