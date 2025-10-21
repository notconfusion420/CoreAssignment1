variable "name" {
  description = "Name prefix for the Data VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the Data VPC"
  type        = string
}

variable "az_a" {
  description = "First availability zone"
  type        = string
}

variable "az_b" {
  description = "Second availability zone"
  type        = string
}

variable "tgw_id" {
  description = "Transit Gateway ID"
  type        = string
}

variable "tgw_route_table_id" {
  description = "Transit Gateway route table ID"
  type        = string
}

variable "spoke_cidrs" {
  description = "List of spoke CIDRs (Hub, App, DB)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags"
  type        = map(string)
  default     = {}
}

variable "hub_dns_ip" {
  description = "Private IP of the hub dnsmasq EC2 used as primary DNS"
  type        = string
}

variable "enable_gateway_endpoints" {
  description = "Create S3/DynamoDB Gateway VPC Endpoints in this VPC"
  type        = bool
  default     = true
}

variable "region" {
  description = "AWS region"
  type        = string
}
