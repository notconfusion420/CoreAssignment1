variable "region" {
  default = "eu-central-1"
}

variable "name" {
  default = "hub-spoke"
}
variable "tags" {
  description = "Extra tags applied to all modules"
  type        = map(string)
  default     = {}
}