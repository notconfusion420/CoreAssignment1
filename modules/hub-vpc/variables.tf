variable "name" {
  description = "Hub"
  type        = string
}

variable "tags" {
  description = ""
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {}
variable "az_a" {}
variable "az_b" {}
variable "tgw_id" {}
variable "tgw_route_table_id" {}

variable "app_vpc_id" {}
variable "data_vpc_id" {}
variable "db_vpc_id" {}

variable "app_vpc_cidr" {}
variable "data_vpc_cidr" {}
variable "db_vpc_cidr" {}

variable "admin_instance_sg_id" {}

variable "spoke_cidrs" {
  type = list(string)
}
