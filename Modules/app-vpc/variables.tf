variable "name" {
  description = "Name prefix for this App VPC"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
variable "spoke_cidrs" {
  description = "CIDRs reachable via TGW (Hub, DB, Data)"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "CIDR block for the App VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "az_a" {
  description = "First AZ"
  type        = string
  default     = "eu-central-1a"
}

variable "az_b" {
  description = "Second AZ"
  type        = string
  default     = "eu-central-1b"
}

variable "tgw_id" {
  description = "Transit Gateway ID"
  type        = string
}

variable "tgw_route_table_id" {
  description = "Transit Gateway Route Table to associate/propagate into"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
