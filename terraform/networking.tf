
resource "aws_vpc" "mongodb" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "mongodb" {
  vpc_id = aws_vpc.mongodb.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Existing public subnets: preserve their Terraform resource addresses.
resource "aws_subnet" "mongodb" {
  count = 3

  vpc_id                  = aws_vpc.mongodb.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  }
}

# Private subnets for MongoDB replica-set members.
resource "aws_subnet" "private" {
  count = 3

  vpc_id                  = aws_vpc.mongodb.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.mongodb.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mongodb.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = 3

  subnet_id      = aws_subnet.mongodb[count.index].id
  route_table_id = aws_route_table.public.id
}

# Elastic IP and NAT Gateway for private-subnet outbound access.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "mongodb" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.mongodb[0].id

  depends_on = [aws_internet_gateway.mongodb]

  tags = {
    Name = "${var.project_name}-nat"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.mongodb.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mongodb.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = 3

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
