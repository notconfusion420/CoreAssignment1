locals {
  name = var.name
  tags = merge(
    try(var.tags, {}),
    { Name = local.name }
  )
}


# AMI
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

# SG for Prometheus + Grafana
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
  ingress {
    description = "tcp"
    from_port   = 22
    to_port     = 22
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

# EC2 that runs Prometheus + Grafana
resource "aws_instance" "this" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = "monitoring-key"

  user_data = <<-EOF
#!/bin/bash
set -e
yum update -y
amazon-linux-extras install docker -y || yum install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

mkdir -p /opt/prometheus

cat >/opt/prometheus/prometheus.yml <<'PROMCFG'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus-self'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'aws-app-ec2'
    static_configs:
      - targets:
          - 10.1.2.10:9100
          - 10.1.4.12:9100
  - job_name: 'wazuh-scrape'
    static_configs:
      - targets:
          - 10.1.2.10:1415

PROMCFG

docker run -d --name prometheus --restart unless-stopped \
  -p 9090:9090 \
  -v /opt/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

docker run -d --name grafana --restart unless-stopped \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  grafana/grafana
  EOF

  tags = merge(local.tags, { Component = "monitoring-ec2" })
}

