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


variable "nat_instance_type" {
  description = "Instance type for NAT EC2"
  type        = string
  default     = "t3.nano"
}

variable "dns_instance_type" {
  description = "Instance type for dnsmasq EC2"
  type        = string
  default     = "t3.nano"
}

variable "allow_ssh_cidr" {
  description = "Optional CIDR for SSH to EC2s (empty = no SSH rule; use SSM)"
  type        = string
  default     = ""
}

variable "dns_forwarder_ip" {
  description = "Upstream DNS for dnsmasq (10.0.0.2 = AmazonProvidedDNS in this VPC range)"
  type        = string
  default     = "10.0.0.2"
}
