locals {
  name = var.name
  tags = merge(
    try(var.tags, {}),
    { Name = local.name }
  )
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name}-vpc" }
}


resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_a_cidr
  availability_zone       = var.az_a
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-private-a" }
}

# Private route table (to TGW for hub/app/db cidrs)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-private" }
}

resource "aws_route" "to_spokes" {
  for_each               = toset(var.spoke_cidrs) # hub cidr, app cidr, db cidr
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = each.value
  transit_gateway_id     = var.tgw_id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

# TGW attachment

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  subnet_ids         = [aws_subnet.private_a.id]
  transit_gateway_id = var.tgw_id
  vpc_id             = aws_vpc.this.id
  tags               = { Name = "${local.name}-tgw-attach" }
}

# Admin EC2 SG

resource "aws_security_group" "admin_ec2_sg" {
  name        = "${local.name}-admin-ec2-sg"
  description = "Admin box allowed to SSH into Wazuh in hub"
  vpc_id      = aws_vpc.this.id

  # We DO NOT allow inbound from the world here unless you want it.
  # You will connect to this admin EC2 some other controlled way (VPN, etc).

  egress {
    description = "All outbound so we can SSH to hub monitoring EC2"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-admin-ec2-sg" }
}

# Admin EC2 

resource "aws_instance" "admin_ec2" {
  ami                         = var.admin_ami_id
  instance_type               = var.admin_instance_type
  subnet_id                   = aws_subnet.private_a.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.admin_ec2_sg.id]

  iam_instance_profile = var.admin_instance_profile_name # give SSM role here too, so you can Systems Manager Session Manager in instead of SSH key

  tags = {
    Name = "${local.name}-admin-ec2"
    Role = "monitoring-admin"
  }
}
