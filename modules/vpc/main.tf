data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /20 subnets carved out of the /16 VPC CIDR.
  # Public subnets use indices 0..az_count-1, private subnets use
  # a fixed offset of 8 so the two ranges never collide, regardless
  # of az_count (supports up to ~8 AZs worth of headroom either side).
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  nat_gateway_count = var.nat_strategy == "per_az" ? var.az_count : 1

  # EKS/ALB Controller subnet auto-discovery tags — only applied if a
  # cluster_name was supplied. Auto Mode and the AWS Load Balancer
  # Controller rely on these to pick subnets without explicit config.
  eks_tags = var.cluster_name != "" ? {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  } : {}

  public_subnet_extra_tags = merge(local.eks_tags, {
    "kubernetes.io/role/elb" = "1"
  })

  private_subnet_extra_tags = merge(local.eks_tags, {
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_vpc" "eks_platform_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_internet_gateway" "eks_platform_igw" {
  vpc_id = aws_vpc.eks_platform_vpc.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_subnet" "eks_platform_public_subnet" {
  count = var.az_count

  vpc_id                  = aws_vpc.eks_platform_vpc.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false # EKS best practice: assign IPs via NAT/ENI, not auto-public

  tags = merge(var.tags, local.public_subnet_extra_tags, {
    Name = "${var.name}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "eks_platform_private_subnet" {
  count = var.az_count

  vpc_id            = aws_vpc.eks_platform_vpc.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, local.private_subnet_extra_tags, {
    Name = "${var.name}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

# --- NAT: single shared, or one per AZ, per var.nat_strategy ---

resource "aws_eip" "eks_platform_nat_eip" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip-${count.index}"
  })

  depends_on = [aws_internet_gateway.eks_platform_igw]
}

resource "aws_nat_gateway" "eks_platform_nat" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.eks_platform_nat_eip[count.index].id
  # single strategy: always place the one NAT GW in the first public subnet.
  # per_az strategy: one NAT GW per public subnet.
  subnet_id = aws_subnet.eks_platform_public_subnet[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.eks_platform_igw]
}

# --- Routing ---

resource "aws_route_table" "eks_platform_public_rt" {
  vpc_id = aws_vpc.eks_platform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_platform_igw.id
  }

  tags = merge(var.tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route_table_association" "eks_platform_public_rta" {
  count = var.az_count

  subnet_id      = aws_subnet.eks_platform_public_subnet[count.index].id
  route_table_id = aws_route_table.eks_platform_public_rt.id
}

# One private route table per AZ so each can point at its own NAT GW
# when nat_strategy = "per_az". Under "single", they all point at NAT[0].
resource "aws_route_table" "eks_platform_private_rt" {
  count = var.az_count

  vpc_id = aws_vpc.eks_platform_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.nat_strategy == "per_az" ? aws_nat_gateway.eks_platform_nat[count.index].id : aws_nat_gateway.eks_platform_nat[0].id
  }

  tags = merge(var.tags, {
    Name = "${var.name}-private-rt-${local.azs[count.index]}"
  })
}

resource "aws_route_table_association" "eks_platform_private_rta" {
  count = var.az_count

  subnet_id      = aws_subnet.eks_platform_private_subnet[count.index].id
  route_table_id = aws_route_table.eks_platform_private_rt[count.index].id
}