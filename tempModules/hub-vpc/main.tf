locals {
  name = var.name
  tags = merge(var.tags, { Name = local.name, Stack = "hub" })
}

# -----------------------------
# VPC + IGW
# -----------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Component = "vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Component = "igw" })
}

# -----------------------------
# Subnets
# -----------------------------
# Public subnet (for NAT GW)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0) # 10.0.0.0/24
  availability_zone       = var.az_a
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Tier = "public", AZ = var.az_a })
}

# Private subnets (Hub services, Resolver, etc.)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1) # 10.0.1.0/24
  availability_zone = var.az_a
  tags              = merge(local.tags, { Tier = "private", AZ = var.az_a })
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2) # 10.0.2.0/24
  availability_zone = var.az_b
  tags              = merge(local.tags, { Tier = "private", AZ = var.az_b })
}

# Subnets for Resolver endpoints
resource "aws_subnet" "resolver_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 3) # 10.0.3.0/24
  availability_zone = var.az_a
  tags              = merge(local.tags, { Tier = "resolver", AZ = var.az_a })
}

resource "aws_subnet" "resolver_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 4) # 10.0.4.0/24
  availability_zone = var.az_b
  tags              = merge(local.tags, { Tier = "resolver", AZ = var.az_b })
}

# -----------------------------
# NAT Gateway
# -----------------------------
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.name}-eip-nat" }
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public_a.id
  allocation_id = aws_eip.nat.id
  tags          = { Name = "${local.name}-nat" }
}

# -----------------------------
# Route Tables
# -----------------------------
# Public RT
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# Private RT -> NAT + TGW routes
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-private" }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route" "to_spokes" {
  for_each               = toset(var.spoke_cidrs)
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = each.value
  transit_gateway_id     = var.tgw_id
}


resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------
# TGW Attachment (+ optional association/propagation)
# -----------------------------
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.tgw_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  #  prevent AWS from auto-associating/propagating
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(local.tags, { Component = "tgw-attach" })
}

resource "aws_ec2_transit_gateway_route_table_association" "assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.tgw_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "prop" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.tgw_route_table_id
}



# -----------------------------
# Security: Resolver SG
# -----------------------------
resource "aws_security_group" "resolver" {
  vpc_id = aws_vpc.this.id
  name   = "${local.name}-resolver-sg"

  ingress {
    description = "DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # tighten later
  }
  ingress {
    description = "DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.tags, { Component = "sg-resolver" })
}

# -----------------------------
# Route 53 Resolver Endpoints
# -----------------------------
resource "aws_route53_resolver_endpoint" "inbound" {
  name               = "${local.name}-inbound"
  direction          = "INBOUND"
  security_group_ids = [aws_security_group.resolver.id]
  ip_address {
    subnet_id = aws_subnet.resolver_a.id
  }
  ip_address {
    subnet_id = aws_subnet.resolver_b.id
  }
  tags = merge(local.tags, { Component = "resolver-inbound" })
}

resource "aws_route53_resolver_endpoint" "outbound" {
  name               = "${local.name}-outbound"
  direction          = "OUTBOUND"
  security_group_ids = [aws_security_group.resolver.id]
  ip_address {
    subnet_id = aws_subnet.resolver_a.id
  }
  ip_address {
    subnet_id = aws_subnet.resolver_b.id
  }
  tags = merge(local.tags, { Component = "resolver-outbound" })
}
