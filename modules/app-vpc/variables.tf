variable "name" {
  description = "App"
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

variable "public_a_cidr" {
  description = "CIDR for public subnet"
  type        = string
}

variable "private_a_cidr" {
  description = "CIDR for private subnet"
  type        = string
}

variable "az_a" {
  description = "Availability zone"
  type        = string
}

variable "tgw_id" {
  description = "Transit Gateway ID"
  type        = string
}

variable "spoke_cidrs" {
  description = "List of spoke CIDRs (Hub/Data/DB)"
  type        = list(string)
}

variable "hub_vpc_cidr" {
  description = "Hub VPC CIDR for security group rules"
  type        = string
}

variable "app_ami_id" {
  description = "AMI ID for App EC2 instance"
  type        = string
}

variable "app_instance_type" {
  description = "Instance type for App EC2"
  type        = string
}

variable "app_instance_profile_name" {
  description = "IAM instance profile for App EC2 (with SSM)"
  type        = string
}
