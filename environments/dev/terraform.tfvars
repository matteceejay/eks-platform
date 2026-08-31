aws_region   = "us-east-1"
environment  = "dev"
vpc_cidr     = "10.0.0.0/16"
az_count     = 2
nat_strategy = "single"

kubernetes_version = "1.33"

endpoint_public_access       = true
endpoint_public_access_cidrs = ["100.38.56.31/32"] # <-- REPLACE with your real office/VPN CIDR(s)

gitops_repo_url        = "https://github.com/matteceejay/eks-platform.git" # <-- REPLACE with your actual repo URL
gitops_target_revision = "main"

tags = {
  ManagedBy = "terraform"
  Team      = "platform"
}

route53_hosted_zone_id = "Z06378293QWI1PIU1LSKR"