variable "name" {
  description = "Name for the TGW"
  type        = string
}

variable "amazon_side_asn" {
  description = "ASN for the TGW (should not overlap with on-prem BGP ASN)"
  type        = number
  default     = 64512
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
