locals {
  name = var.name
  tags = merge(
    try(var.tags, {}),
    { Name = local.name }
  )
}

# -----------------------------
# VPC
# -----------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Component = "vpc" })
}

# -----------------------------
# Subnets
# -----------------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_a_cidr
  availability_zone       = var.az_a
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Tier = "public", AZ = var.az_a })
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_a_cidr
  availability_zone       = var.az_a
  map_public_ip_on_launch = false
  tags                    = merge(local.tags, { Tier = "private", AZ = var.az_a })
}

# -----------------------------
# Internet Gateway + Routes
# -----------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Component = "igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-rt-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------
# Private Routes + TGW
# -----------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-rt-private" })
}

# Routes to Hub/Data/DB via TGW
resource "aws_route" "to_hub_data_db" {
  for_each               = toset(var.spoke_cidrs)
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = each.value
  transit_gateway_id     = var.tgw_id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------
# TGW Attachment
# -----------------------------
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  subnet_ids         = [aws_subnet.private_a.id]
  transit_gateway_id = var.tgw_id
  vpc_id             = aws_vpc.this.id
  tags               = merge(local.tags, { Component = "tgw-attach" })
}

# -----------------------------
# Security Groups
# -----------------------------
# ALB SG: open 80/443 to internet
resource "aws_security_group" "alb_sg" {
  name   = "${local.name}-alb-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "sg-alb" })
}

# App EC2 SG: allows traffic from ALB SG
resource "aws_security_group" "app_ec2_sg" {
  name        = "${local.name}-app-ec2-sg"
  description = "App instance SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "App port from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Wazuh communications
  egress {
    description = "TCP 1514 to Hub Wazuh"
    from_port   = 1514
    to_port     = 1514
    protocol    = "tcp"
    cidr_blocks = [var.hub_vpc_cidr]
  }

  egress {
    description = "UDP 1514 to Hub Wazuh"
    from_port   = 1514
    to_port     = 1514
    protocol    = "udp"
    cidr_blocks = [var.hub_vpc_cidr]
  }

  egress {
    description = "TCP 55000 to Hub Wazuh (enroll)"
    from_port   = 55000
    to_port     = 55000
    protocol    = "tcp"
    cidr_blocks = [var.hub_vpc_cidr]
  }

  egress {
    description = "All other egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "sg-app-ec2" })
}

# -----------------------------
# Application Load Balancer
# -----------------------------
resource "aws_lb" "app_alb" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id]
  security_groups    = [aws_security_group.alb_sg.id]
  tags               = merge(local.tags, { Component = "alb" })
}

# -----------------------------
# EC2 App Instance
# -----------------------------
resource "aws_instance" "app_instance" {
  ami                         = var.app_ami_id
  instance_type               = var.app_instance_type
  subnet_id                   = aws_subnet.private_a.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app_ec2_sg.id]
  iam_instance_profile        = var.app_instance_profile_name

  tags = merge(local.tags, {
    Name = "${local.name}-app-ec2"
    Role = "application"
  })
}
