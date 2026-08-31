# environments/prod/terraform.tfvars
aws_region   = "us-east-1"
environment  = "prod"
vpc_cidr     = "10.2.0.0/16"
az_count     = 3
nat_strategy = "per_az"

kubernetes_version = "1.33"

# Prod: no public endpoint at all. Access the API server via VPN/bastion/
# Transit Gateway into the VPC, or a CI runner deployed inside it.
endpoint_public_access       = false
endpoint_public_access_cidrs = []

gitops_repo_url        = "https://github.com/matteceejay/eks-platform.git" # <-- REPLACE with your actual repo URL
gitops_target_revision = "main" # consider pinning prod to a release tag instead of a branch

tags = {
  ManagedBy = "terraform"
  Team      = "platform"
}