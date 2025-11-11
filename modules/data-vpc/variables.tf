variable "name" {
  description = "Data"
  type        = string
}

variable "tags" {
  description = "Tags applied to resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
}
variable "private_a_cidr" {}
variable "az_a" {}
variable "tgw_id" {}
variable "spoke_cidrs" {
  type = list(string)
}

variable "admin_ami_id" {}
variable "admin_instance_type" {}
variable "admin_instance_profile_name" {}
