############################################
# ONE-TIME BOOTSTRAP
# Run this manually, once, before any environment.
# This creates the S3 bucket that will hold Terraform
# state for dev, staging, and prod (separate keys/prefixes).
#
# This config itself uses LOCAL state — it's a chicken-and-egg
# resource, it can't store its own state in the bucket it creates.
# Run it once, then leave it alone.
############################################

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "eks_platform_terraform_state" {
  bucket = var.state_bucket_name

  # Safety net: prevents `terraform destroy` from deleting
  # the bucket that holds every environment's state.
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "eks_platform_terraform_state" {
  bucket = aws_s3_bucket.eks_platform_terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "eks_platform_terraform_state" {
  bucket = aws_s3_bucket.eks_platform_terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.eks_platform_terraform_state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "eks_platform_terraform_state" {
  bucket = aws_s3_bucket.eks_platform_terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "eks_platform_terraform_state" {
  description             = "KMS key for Terraform state bucket encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "eks_platform_terraform_state" {
  name          = "alias/terraform-state-${var.state_bucket_name}"
  target_key_id = aws_kms_key.eks_platform_terraform_state.key_id
}