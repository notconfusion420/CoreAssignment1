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
# Public subnet (for NAT instance)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0) # 10.0.0.0/24
  availability_zone       = var.az_a
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Tier = "public", AZ = var.az_a })
}

# Private subnets (Hub services, internal workloads)
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

# -----------------------------
# AMI (Amazon Linux 2)
# -----------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# -----------------------------
# IAM for SSM (no SSH required)
# -----------------------------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm_role" {
  name               = "${local.name}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = merge(local.tags, { Component = "iam-role-ssm" })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${local.name}-ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# -----------------------------
# Security Groups
# -----------------------------
# NAT SG: allow forwarding from the whole VPC; egress anywhere
resource "aws_security_group" "nat_sg" {
  vpc_id = aws_vpc.this.id
  name   = "${local.name}-nat-sg"

  ingress {
    description = "Allow VPC traffic for NAT forwarding"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # (Optional) temporary SSH from your IP while testing
  # ingress {
  #   description = "SSH (temporary)"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["85.145.236.171/32"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "sg-nat" })
}

# DNS SG: allow DNS from VPC; egress anywhere
resource "aws_security_group" "dns_sg" {
  vpc_id = aws_vpc.this.id
  name   = "${local.name}-dns-sg"

  ingress {
    description = "DNS TCP from VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "DNS UDP from VPC"
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

  tags = merge(local.tags, { Component = "sg-dns" })
}

# -----------------------------
# EC2 NAT Instance (replacement for NAT Gateway)
# -----------------------------
resource "aws_instance" "nat_instance" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.nano"
  subnet_id                   = aws_subnet.public_a.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids      = [aws_security_group.nat_sg.id]
  source_dest_check           = false
  # key_name                  = null  # use SSM instead of SSH keys

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    yum update -y
    yum install -y iptables-services
    systemctl enable amazon-ssm-agent || true
    systemctl start amazon-ssm-agent || true
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1
    # NAT (masquerade) and forwarding rules
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -s ${var.vpc_cidr} -j ACCEPT
    service iptables save
    systemctl enable iptables
  EOF

  tags = merge(local.tags, { Name = "${local.name}-nat-instance" })
}

# Allocate an Elastic IP in the VPC domain
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = merge(local.tags, { Component = "nat-eip" })
}

# Associate the EIP to the NAT instance
resource "aws_eip_association" "nat_eip_assoc" {
  instance_id   = aws_instance.nat_instance.id
  allocation_id = aws_eip.nat_eip.id
}


# -----------------------------
# EC2 DNS Resolver (dnsmasq)
# -----------------------------
resource "aws_instance" "dns_proxy" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.nano"
  subnet_id                   = aws_subnet.private_a.id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids      = [aws_security_group.dns_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    yum update -y
    yum install -y dnsmasq
    IP=$(hostname -I | awk '{print $1}')
    cat >/etc/dnsmasq.d/custom.conf <<CFG
listen-address=$${IP}
bind-interfaces
no-resolv
cache-size=1000
# Forward to AmazonProvidedDNS in this VPC (always .2 of VPC base)
server=10.0.0.2
# Optional conditional forward example:
# server=/corp.local/10.0.0.2
log-queries
log-facility=/var/log/dnsmasq.log
CFG
    systemctl enable dnsmasq
    systemctl restart dnsmasq
  EOF

  tags = merge(local.tags, { Name = "${local.name}-dns-proxy" })
}

# Make VPC use our DNS first, fall back to AmazonProvidedDNS
resource "aws_vpc_dhcp_options" "this" {
  domain_name_servers = [aws_instance.dns_proxy.private_ip, "10.0.0.2"]
  tags                = merge(local.tags, { Component = "dhcp" })
}

resource "aws_vpc_dhcp_options_association" "assoc" {
  vpc_id          = aws_vpc.this.id
  dhcp_options_id = aws_vpc_dhcp_options.this.id
}

# -----------------------------
# Route Tables
# -----------------------------
# Public route table (for NAT instance internet access)
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

# Private route table -> NAT instance + TGW routes
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-private" }
}

# Private traffic to internet through EC2 NAT (use ENI to avoid provider quirks)
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance.primary_network_interface_id
}

# Routes to spoke VPCs via TGW
resource "aws_route" "to_spokes" {
  for_each               = toset(var.spoke_cidrs)
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = each.value
  transit_gateway_id     = var.tgw_id
}

# Route table associations
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------
# TGW Attachment
# -----------------------------
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.tgw_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]

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
