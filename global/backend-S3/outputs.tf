output "state_bucket_name" {
  value       = aws_s3_bucket.eks_platform_terraform_state.id
  description = "Name to reference in each environment's backend.tf"
}

output "state_bucket_kms_key_arn" {
  value = aws_kms_key.eks_platform_terraform_state.arn
}