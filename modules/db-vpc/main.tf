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
  tags                 = merge(local.tags, { Component = "vpc" })
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0)
  availability_zone       = var.az_a
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Tier = "public", AZ = var.az_a })
}

resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = var.az_a
  tags              = merge(local.tags, { Tier = "private-db", AZ = var.az_a })
}

resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = var.az_b
  tags              = merge(local.tags, { Tier = "private-db", AZ = var.az_b })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Component = "igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-private" }
}

resource "aws_route" "private_to_tgw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.tgw_id
}

resource "aws_route" "to_spokes" {
  for_each               = toset(var.spoke_cidrs)
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = each.value
  transit_gateway_id     = var.tgw_id
}

resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.db_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_b" {
  subnet_id      = aws_subnet.db_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_dhcp_options" "dns" {
  domain_name_servers = [var.hub_dns_ip, cidrhost(var.vpc_cidr, 2)]
  tags                = merge(local.tags, { Component = "dhcp-dns" })
}

resource "aws_vpc_dhcp_options_association" "dns_assoc" {
  vpc_id          = aws_vpc.this.id
  dhcp_options_id = aws_vpc_dhcp_options.dns.id
}

resource "aws_vpc_endpoint" "s3" {
  count             = var.enable_s3_gateway_endpoint ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = merge(local.tags, { Component = "vpce-s3" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id                              = var.tgw_id
  vpc_id                                          = aws_vpc.this.id
  subnet_ids                                      = [aws_subnet.db_a.id, aws_subnet.db_b.id]
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

resource "aws_security_group" "db" {
  vpc_id = aws_vpc.this.id
  name   = "${local.name}-rds-sg"

  ingress {
    description = "MySQL/Postgres/etc from Hub/App/Data"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "sg-rds" })
}

resource "aws_security_group" "redis" {
  vpc_id = aws_vpc.this.id
  name   = "${local.name}-redis-sg"

  ingress {
    description = "Redis from Hub/App/Data"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Component = "sg-redis" })
}

resource "aws_db_subnet_group" "db" {
  name       = "${local.name}-db-subnets"
  subnet_ids = [aws_subnet.db_a.id, aws_subnet.db_b.id]
  tags       = merge(local.tags, { Component = "rds-subnet-group" })
}

resource "aws_db_instance" "this" {
  identifier        = "${local.name}-rds"
  engine            = var.rds_engine
  engine_version    = var.rds_engine_version
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  multi_az          = var.rds_multi_az

  username = var.rds_username
  password = var.rds_password

  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.db.name

  publicly_accessible = false
  storage_encrypted   = true
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  tags = merge(local.tags, { Component = "rds" })
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name}-redis-subnets"
  subnet_ids = [aws_subnet.db_a.id, aws_subnet.db_b.id]
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${local.name}-redis"
  description                = "Redis for ${local.name}"
  engine                     = "redis"
  engine_version             = var.redis_engine_version
  node_type                  = var.redis_node_type
  num_cache_clusters         = var.redis_num_nodes
  automatic_failover_enabled = false
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  port                       = 6379
  tags                       = merge(local.tags, { Component = "redis" })
}

resource "aws_s3_bucket" "data" {
  count  = var.enable_s3 ? 1 : 0
  bucket = var.s3_bucket_name
  tags   = merge(local.tags, { Component = "s3" })
}

resource "aws_s3_bucket_public_access_block" "data" {
  count                   = var.enable_s3 ? 1 : 0
  bucket                  = aws_s3_bucket.data[0].id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "oac" {
  count                             = var.enable_s3 && var.enable_cloudfront ? 1 : 0
  name                              = "${local.name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  count = var.enable_s3 && var.enable_cloudfront ? 1 : 0

  origin {
    domain_name              = aws_s3_bucket.data[0].bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac[0].id
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate { cloudfront_default_certificate = true }

  tags = merge(local.tags, { Component = "cloudfront" })
}

resource "aws_s3_bucket_policy" "data" {
  count  = var.enable_s3 && var.enable_cloudfront ? 1 : 0
  bucket = aws_s3_bucket.data[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowCloudFrontOAC",
      Effect    = "Allow",
      Principal = { Service = "cloudfront.amazonaws.com" },
      Action    = ["s3:GetObject"],
      Resource  = ["${aws_s3_bucket.data[0].arn}/*"],
      Condition = { StringEquals = { "AWS:SourceArn" : aws_cloudfront_distribution.this[0].arn } }
    }]
  })
}
