locals {
  tags = merge(var.tags, { Name = var.name, Stack = "monitoring" })
}

# Find latest Amazon Linux 2 AMI
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

# Security Group for Prometheus + Grafana
resource "aws_security_group" "this" {
  name        = "${var.name}-mon-sg"
  description = "Monitoring SG"
  vpc_id      = var.vpc_id

  ingress {
    description = "Grafana (3000)"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "Prometheus (9090)"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "sg-monitoring" })
}

# Monitoring EC2 (key-based login)
resource "aws_instance" "this" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = var.key_name   # <-- your EC2 key pair

user_data = <<-EOF
  #!/bin/bash
  set -e
  yum update -y
  amazon-linux-extras install docker -y || yum install -y docker
  systemctl enable docker
  systemctl start docker
  usermod -aG docker ec2-user
  # Prometheus
  docker run -d --name prometheus --restart unless-stopped \
    -p 9090:9090 prom/prometheus
  # Grafana
  docker run -d --name grafana --restart unless-stopped \
    -p 3000:3000 \
    -e GF_SECURITY_ADMIN_PASSWORD=admin \
    grafana/grafana
EOF

  tags = merge(local.tags, { Component = "monitoring-ec2" })
}
