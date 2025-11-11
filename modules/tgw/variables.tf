variable "name" {
  description = "TGW"
  type        = string
}

variable "tags" {
  description = ""
  type        = map(string)
  default     = {}
}


variable "amazon_side_asn" {
  description = "ASN for the TGW (should not overlap with on-prem BGP ASN)"
  type        = number
  default     = 64512
}

