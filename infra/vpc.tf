################################################################################
# VPC
################################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = local.name_prefix }
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = local.name_prefix }
}

################################################################################
# Public Subnets (ALB)
################################################################################

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name_prefix}-public-${local.azs[count.index]}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name_prefix}-public" }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

################################################################################
# NAT Gateway (single AZ — sufficient for dev)
# Required so ECS tasks can reach public AWS endpoints such as the ALB JWT
# public-key service (public-keys.auth.elb.<region>.amazonaws.com).
################################################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "${local.name_prefix}-nat" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = { Name = local.name_prefix }

  depends_on = [aws_internet_gateway.main]
}

################################################################################
# Private Subnets (ECS Fargate)
################################################################################

resource "aws_subnet" "private" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = { Name = "${local.name_prefix}-private-${local.azs[count.index]}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "${local.name_prefix}-private" }
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

################################################################################
# DB Subnets (RDS)
################################################################################

resource "aws_subnet" "db" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.db_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = { Name = "${local.name_prefix}-db-${local.azs[count.index]}" }
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-db" }
}

resource "aws_route_table_association" "db" {
  count = 2

  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}
