# modules/tgw/main.tf
locals {
  name = var.name
  tags = merge(var.tags, { Name = local.name })
}

resource "aws_ec2_transit_gateway" "this" {
  description                     = "${local.name} TGW"
  amazon_side_asn                 = var.amazon_side_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "enable"
  tags                            = local.tags
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(local.tags, { Component = "tgw-rt" })
}
