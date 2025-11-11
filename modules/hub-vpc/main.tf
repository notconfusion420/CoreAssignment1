locals {
  name = var.name
  tags = merge(
    try(var.tags, {}),
    { Name = local.name }
  )
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
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0)
  availability_zone       = var.az_a
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Tier = "public", AZ = var.az_a })
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = var.az_a
  tags              = merge(local.tags, { Tier = "private", AZ = var.az_a })
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
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
# IAM for SSM (shared)
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
  name               = "${local.name}-ec2-ssm-role-v2"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = merge(local.tags, { Component = "iam-role-ssm" })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${local.name}-ec2-ssm-profile-v2"
  role = aws_iam_role.ssm_role.name
}

# -----------------------------
# Security Groups
# -----------------------------
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "sg-nat" })
}

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
# NAT Instance
# -----------------------------
resource "aws_instance" "nat_instance" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.nano"
  subnet_id                   = aws_subnet.public_a.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids      = [aws_security_group.nat_sg.id]
  source_dest_check           = false

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    yum update -y
    yum install -y iptables-services
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -s ${var.vpc_cidr} -j ACCEPT
    service iptables save
    systemctl enable iptables
  EOF

  tags = merge(local.tags, { Name = "${local.name}-nat-instance" })
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = merge(local.tags, { Component = "nat-eip" })
}

resource "aws_eip_association" "nat_eip_assoc" {
  instance_id   = aws_instance.nat_instance.id
  allocation_id = aws_eip.nat_eip.id
}

# -----------------------------
# DNS Resolver EC2 (dnsmasq)
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
server=10.0.0.2
log-queries
log-facility=/var/log/dnsmasq.log
CFG
    systemctl enable dnsmasq
    systemctl restart dnsmasq
  EOF

  tags = merge(local.tags, { Name = "${local.name}-dns-proxy" })
}

resource "aws_vpc_dhcp_options" "this" {
  domain_name_servers = [aws_instance.dns_proxy.private_ip, "10.0.0.2"]
  tags                = merge(local.tags, { Component = "dhcp" })
}

resource "aws_vpc_dhcp_options_association" "assoc" {
  vpc_id          = aws_vpc.this.id
  dhcp_options_id = aws_vpc_dhcp_options.this.id
}

# ======================================================================
# Monitoring EC2 
# ======================================================================

resource "aws_security_group" "wazuh_monitoring_sg" {
  vpc_id = aws_vpc.this.id
  name   = "${local.name}-wazuh-monitoring-sg"

  # from App/Data/DB VPCs via TGW
  ingress {
    description = "Wazuh agent TCP 1514"
    from_port   = 1514
    to_port     = 1514
    protocol    = "tcp"
    cidr_blocks = [var.app_vpc_cidr, var.data_vpc_cidr, var.db_vpc_cidr]
  }
  ingress {
    description = "Wazuh agent UDP 1514"
    from_port   = 1514
    to_port     = 1514
    protocol    = "udp"
    cidr_blocks = [var.app_vpc_cidr, var.data_vpc_cidr, var.db_vpc_cidr]
  }
  ingress {
    description = "Wazuh enrollment TCP 55000"
    from_port   = 55000
    to_port     = 55000
    protocol    = "tcp"
    cidr_blocks = [var.app_vpc_cidr, var.data_vpc_cidr, var.db_vpc_cidr]
  }
  ingress {
    description     = "SSH from Admin EC2 SG"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.admin_instance_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "sg-wazuh" })
}

# --- IAM for monitoring EC2
resource "aws_iam_role" "wazuh_ssm_role" {
  name               = "${local.name}-wazuh-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = merge(local.tags, { Component = "iam-role-wazuh" })
}

resource "aws_iam_role_policy_attachment" "wazuh_ssm_attach" {
  role       = aws_iam_role.wazuh_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "wazuh_ssm_profile" {
  name = "${local.name}-wazuh-ssm-profile"
  role = aws_iam_role.wazuh_ssm_role.name
}

# --- Wazuh monitoring EC2
resource "aws_instance" "wazuh_monitor" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.xlarge"
  subnet_id                   = aws_subnet.private_a.id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.wazuh_ssm_profile.name
  vpc_security_group_ids      = [aws_security_group.wazuh_monitoring_sg.id]

  root_block_device {
    volume_size = 200
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    yum install -y curl unzip
    curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh
    bash wazuh-install.sh -a
    hostnamectl set-hostname wazuh.service.local || true
  EOF

  tags = merge(local.tags, { Name = "${local.name}-wazuh-monitor" })
}

# --- Route53 Private Hosted Zone and A-record
resource "aws_route53_zone" "svc_local" {
  name = "service.local"

  vpc { vpc_id = aws_vpc.this.id }
  vpc { vpc_id = var.app_vpc_id }
  vpc { vpc_id = var.data_vpc_id }
  vpc { vpc_id = var.db_vpc_id }

  comment = "Internal service discovery zone"
  tags    = merge(local.tags, { Component = "r53-zone" })
}

resource "aws_route53_record" "wazuh_dns" {
  zone_id = aws_route53_zone.svc_local.zone_id
  name    = "wazuh.service.local"
  type    = "A"
  ttl     = 30
  records = [aws_instance.wazuh_monitor.private_ip]
}

# -----------------------------
# Route Tables
# -----------------------------
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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-private" }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance.primary_network_interface_id
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
# TGW Attachment
# -----------------------------
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id                              = var.tgw_id
  vpc_id                                          = aws_vpc.this.id
  subnet_ids                                      = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags                                            = merge(local.tags, { Component = "tgw-attach" })
}

resource "aws_ec2_transit_gateway_route_table_association" "assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.tgw_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "prop" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.tgw_route_table_id
}
