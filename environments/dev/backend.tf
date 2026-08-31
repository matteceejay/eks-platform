terraform {
  required_version = ">= 1.11.0"

  backend "s3" {
    bucket       = "handart-eks-platform" # output of global/backend-bootstrap
    key          = "eks-platform/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 locking (TF >= 1.11) — no DynamoDB table needed
  }
}