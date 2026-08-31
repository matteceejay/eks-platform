output "vpc_id" {
  value = aws_vpc.eks_platform_vpc.id
}

output "vpc_cidr" {
  value = aws_vpc.eks_platform_vpc.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.eks_platform_public_subnet[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.eks_platform_private_subnet[*].id
}

output "availability_zones" {
  value = local.azs
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.eks_platform_nat[*].id
}