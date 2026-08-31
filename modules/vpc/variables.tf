# modules/vpc/variables.tf
variable "name" {
  description = "Name prefix for all VPC resources (e.g. eks_platform-dev)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across (2 for dev, 3 for prod)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 6
    error_message = "az_count must be between 2 and 6."
  }
}

variable "nat_strategy" {
  description = "single = one shared NAT Gateway (cheaper, less HA). per_az = one NAT Gateway per AZ (prod-grade HA, higher cost)."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per_az"], var.nat_strategy)
    error_message = "nat_strategy must be either \"single\" or \"per_az\"."
  }
}

variable "cluster_name" {
  description = "EKS cluster name, used only to apply the kubernetes.io/cluster/<name> and elb discovery tags subnets need for the AWS Load Balancer Controller and EKS Auto Mode to auto-discover them. Leave blank to skip."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags applied to all resources, merged with EKS cluster discovery tags in the calling environment"
  type        = map(string)
  default     = {}
}