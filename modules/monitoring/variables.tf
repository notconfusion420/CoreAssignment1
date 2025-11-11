variable "name" {
  description = "Mon"
  type        = string
}

variable "tags" {
  description = ""
  type        = map(string)
  default     = {}
}


variable "vpc_id" {}
variable "subnet_id" {}
variable "instance_type" {}
variable "allowed_cidrs" {
  type = list(string)
}

# optional key name if needed
variable "key_name" {
  default = null
}
