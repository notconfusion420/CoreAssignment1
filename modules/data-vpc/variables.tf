variable "name" {
  description = "Name prefix for the App VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the App VPC"
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
  description = "List of spoke CIDRs (Hub, DB, Data)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags"
  type        = map(string)
  default     = {}
}
