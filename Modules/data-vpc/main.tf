locals {
  name = var.name
  tags = merge(var.tags, { Name = local.name, Stack = "data-spoke" })
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
# Subnets (multi-AZ)
# -----------------------------
resource "aws_subnet" "data_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1) # 10.3.1.0/24
  availability_zone = var.az_a
  tags              = merge(local.tags, { Tier = "private-data", AZ = var.az_a })
}

resource "aws_subnet" "data_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2) # 10.3.2.0/24
  availability_zone = var.az_b
  tags              = merge(local.tags, { Tier = "private-data", AZ = var.az_b })
}

# -----------------------------
# Route Table (private via TGW)
# -----------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Tier = "private" })
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.data_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.data_b.id
  route_table_id = aws_route_table.private.id
}

# Default route → TGW (so Data VPC uses Hub NAT for internet)
resource "aws_route" "default_via_tgw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.tgw_id
}

# Routes to Hub/App/DB via TGW
resource "aws_route" "to_spokes" {
  for_each               = toset(var.spoke_cidrs)
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = each.value
  transit_gateway_id     = var.tgw_id
}

# -----------------------------
# IAM Role for SSM (Systems Manager)
# -----------------------------
resource "aws_iam_role" "ssm_role" {
  name = "${var.name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${var.name}-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# -----------------------------
# TGW Attachment
# -----------------------------
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id                              = var.tgw_id
  vpc_id                                          = aws_vpc.this.id
  subnet_ids                                      = [aws_subnet.data_a.id, aws_subnet.data_b.id]
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
# Security Group
# -----------------------------
resource "aws_security_group" "data_ec2" {
  name        = "${var.name}-ec2-sg"
  description = "Allow admin access via Hub"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH from Hub CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Hub VPC CIDR
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "ec2-sg" })
}

# -----------------------------
# EC2 Instance (admin/data box)
# -----------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "data" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.data_a.id
  vpc_security_group_ids = [aws_security_group.data_ec2.id]

  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "${var.name}-ec2"
  }
}
