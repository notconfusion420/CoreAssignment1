output "vpc_id" {
  value = aws_vpc.this.id
}

output "dmz_subnet_id" {
  value = aws_subnet.dmz_a.id
}

output "app_subnet_id" {
  value = aws_subnet.app_a.id
}

# DHCP options so you can verify the spoke is using hub DNS
output "dhcp_options_id" {
  value = aws_vpc_dhcp_options.dns.id
}

# Route tables (useful for troubleshooting and wiring)
output "dmz_route_table_id" {
  value = aws_route_table.dmz.id
}

output "app_private_route_table_id" {
  value = aws_route_table.app_private.id
}

# Security groups (often useful to reference from other modules)
output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "app_ec2_sg_id" {
  value = aws_security_group.app_ec2.id
}

# TGW attachment (handy for TGW RT operations from a root module)
output "tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.this.id
}
