# -----------------------------
# General
# -----------------------------
variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "region" {
  description = "AWS region (used for endpoints, AZs, etc.)"
  type        = string
}

variable "vpc_cidr" {
  description = "DB VPC CIDR"
  type        = string
  default     = "10.2.0.0/16"
}

variable "az_a" {
  description = "First Availability Zone"
  type        = string
  default     = "eu-central-1a"
}

variable "az_b" {
  description = "Second Availability Zone"
  type        = string
  default     = "eu-central-1b"
}

# -----------------------------
# TGW + Spoke Integration
# -----------------------------
variable "tgw_id" {
  description = "Transit Gateway ID"
  type        = string
}

variable "tgw_route_table_id" {
  description = "Transit Gateway Route Table ID for association/propagation"
  type        = string
  default     = ""
}

variable "spoke_cidrs" {
  description = "CIDRs reachable via TGW (Hub, App, Data)"
  type        = list(string)
  default     = []
}

# -----------------------------
# Shared Services
# -----------------------------
variable "enable_s3_gateway_endpoint" {
  description = "Enable Gateway VPC Endpoint for S3 (reduces NAT egress)"
  type        = bool
  default     = true
}

# -----------------------------
# RDS Parameters
# -----------------------------
variable "rds_engine" {
  description = "RDS engine type (mysql, postgres, etc.)"
  type        = string
  default     = "mysql"
}

variable "rds_engine_version" {
  description = "Version of the RDS engine"
  type        = string
  default     = "8.0"
}

variable "rds_instance_class" {
  description = "RDS instance size"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage (GB)"
  type        = number
  default     = 20
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "rds_username" {
  description = "Master username"
  type        = string
  default     = "admin"
}

variable "rds_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

# -----------------------------
# Redis Parameters
# -----------------------------
variable "redis_node_type" {
  description = "Instance type for Redis"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_nodes" {
  description = "Number of Redis nodes"
  type        = number
  default     = 1
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

# -----------------------------
# Network Security
# -----------------------------
variable "ingress_cidrs" {
  description = "CIDRs allowed to reach RDS (3306) and Redis (6379)"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

# -----------------------------
# S3 / CloudFront
# -----------------------------
variable "enable_s3" {
  description = "Deploy S3 bucket for static assets/backups"
  type        = bool
  default     = false
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket (required if enable_s3 = true)"
  type        = string
  default     = ""
}

variable "enable_cloudfront" {
  description = "Deploy CloudFront distribution in front of S3"
  type        = bool
  default     = false
}

# -----------------------------
# Tags
# -----------------------------
variable "tags" {
  description = "Extra tags to merge with defaults"
  type        = map(string)
  default     = {}
}
