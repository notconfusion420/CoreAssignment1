locals {
  name = var.name
  tags = merge(var.tags, { Name = local.name, Stack = "app-spoke" })
}

# ------------------------------
# VPC
# ------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Component = "vpc" })
}

# ------------------------------
# VPC
# ------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Component = "vpc" })
}
# -----------------------------
# Subnets
# -----------------------------

# DMZ subnets for ALB (public, has IGW)
resource "aws_subnet" "dmz_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1) # 10.1.1.0/24
  availability_zone       = var.az_a
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Tier = "dmz", AZ = var.az_a })
}

resource "aws_subnet" "dmz_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 3) # 10.1.3.0/24
  availability_zone       = var.az_b
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Tier = "dmz", AZ = var.az_b })
}

# App subnets for EC2 (private, no IGW; outbound via TGW → Hub NAT)
resource "aws_subnet" "app_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2) # 10.1.2.0/24
  availability_zone = var.az_a
  tags              = merge(local.tags, { Tier = "private-app", AZ = var.az_a })
}

resource "aws_subnet" "app_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 4) # 10.1.4.0/24
  availability_zone = var.az_b
  tags              = merge(local.tags, { Tier = "private-app", AZ = var.az_b })
}

# -----------------------------
# IGW + Route Tables
# -----------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Component = "igw" })
}

# Public/DMZ route table (ALB needs internet)
resource "aws_route_table" "dmz" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Tier = "dmz" })
}

resource "aws_route" "dmz_internet" {
  route_table_id         = aws_route_table.dmz.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate BOTH DMZ subnets
resource "aws_route_table_association" "dmz_assoc_a" {
  subnet_id      = aws_subnet.dmz_a.id
  route_table_id = aws_route_table.dmz.id
}
resource "aws_route_table_association" "dmz_assoc_b" {
  subnet_id      = aws_subnet.dmz_b.id
  route_table_id = aws_route_table.dmz.id
}

# Private app route table (default via TGW → Hub → NAT)
resource "aws_route_table" "app_private" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Tier = "private-app" })
}

resource "aws_route" "app_to_internet_via_hub" {
  route_table_id         = aws_route_table.app_private.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.tgw_id
}

# (Optional) routes to other spokes can be added here if you want explicit entries,
# but TGW RT usually handles inter-spoke routing

# Associate BOTH private subnets
resource "aws_route_table_association" "app_assoc_a" {
  subnet_id      = aws_subnet.app_a.id
  route_table_id = aws_route_table.app_private.id
}
resource "aws_route_table_association" "app_assoc_b" {
  subnet_id      = aws_subnet.app_b.id
  route_table_id = aws_route_table.app_private.id
}

# -----------------------------
# TGW Attachment (now multi-AZ)
# -----------------------------
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.tgw_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = [aws_subnet.app_a.id, aws_subnet.app_b.id] # HA across AZs

  tags = merge(local.tags, { Component = "tgw-attach" })
}

############################
# Security Groups
############################
# SG for ALB (public-facing)
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Allow HTTP from internet to ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # If/when you add HTTPS:
  # ingress {
  #   description = "Allow HTTPS"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "alb-sg" })
}

# SG for EC2 (private instances) — only ALB can reach them
resource "aws_security_group" "app_ec2" {
  name        = "${var.name}-ec2-sg"
  description = "Allow traffic from ALB to EC2"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "ec2-sg" })
}

############################
# AMI lookup
############################
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

############################
# Application Load Balancer
############################
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.dmz_a.id, aws_subnet.dmz_b.id]

  tags = merge(local.tags, { Component = "alb" })
}

resource "aws_lb_target_group" "app" {
  name     = "${var.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.tags, { Component = "tg" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

############################
# HA EC2: Launch Template + Auto Scaling Group
############################
resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app_ec2.id]

  # Optional: give the instances a simple web page to prove traffic flows
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "<h1>${var.name} - $(hostname)</h1>" > /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.tags, { Component = "app-ec2" })
  }

  tags = merge(local.tags, { Component = "lt" })
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.name}-asg"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.app_a.id, aws_subnet.app_b.id] # spread across both AZs
  health_check_type         = "ELB"
  health_check_grace_period = 90
  target_group_arns         = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Tags must be in blocks, not a merge()
  tag {
    key                 = "Name"
    value               = "${var.name}-ec2"
    propagate_at_launch = true
  }

  tag {
    key                 = "Component"
    value               = "asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Stack"
    value               = "app-spoke"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb_listener.http]
}

