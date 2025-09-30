locals {
  name = var.name
  tags = merge(var.tags, { Name = local.name })
}

# Create the Transit Gateway
resource "aws_ec2_transit_gateway" "this" {
  description                     = "${local.name} TGW"
  amazon_side_asn                 = var.amazon_side_asn
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments  = "enable" # using Resource Access Manager

  tags = local.tags
}

# Create a default TGW route table
resource "aws_ec2_transit_gateway_route_table" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(local.tags, { Component = "tgw-rt" })
}

# Example default route to internet (optional)
# (usually you'll add VPC attachments to this table instead)
# resource "aws_ec2_transit_gateway_route" "default" {
#   transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
#   destination_cidr_block         = "0.0.0.0/0"
#   blackhole                      = true
# }

