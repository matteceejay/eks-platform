terraform {
  required_version = ">= 1.11.0"

  backend "s3" {
    bucket       = "REPLACE_WITH_STATE_BUCKET_NAME" # output of global/backend-bootstrap
    key          = "eks-platform/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 locking (TF >= 1.11) — no DynamoDB table needed
  }
}