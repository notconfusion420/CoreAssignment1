variable "name" {
  description = "Name prefix"
  type        = string
}

variable "vpc_id" {
  description = "Hub VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the monitoring EC2"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair for SSH login"
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach Grafana/Prometheus"
  type        = list(string)
  default     = ["0.0.0.0/0"] # for testing; restrict later
}

variable "instance_type" {
  description = "EC2 size"
  type        = string
  default     = "t3.small"
}

variable "tags" {
  type    = map(string)
  default = {}
}
