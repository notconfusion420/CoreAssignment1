variable "name" {
  description = "Name prefix for Hub VPC"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "Hub VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
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
  description = "TGW RT to associate/propagate Hub"
  type        = string
  default     = ""
}

variable "spoke_cidrs" {
  description = "List of spoke CIDRs routable via TGW"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags"
  type        = map(string)
  default     = {}
}
