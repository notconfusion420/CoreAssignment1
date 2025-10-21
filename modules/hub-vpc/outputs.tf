# Core VPC + subnets
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_a.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

# TGW attachment
output "tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.this.id
}


# NAT instance / EIP
output "nat_instance_id" {
  value = aws_instance.nat_instance.id
}

output "nat_eip_public_ip" {
  value = aws_eip.nat_eip.public_ip
}

# DNS instance
output "dns_instance_id" {
  value = aws_instance.dns_proxy.id
}

output "dns_instance_private_ip" {
  value = aws_instance.dns_proxy.private_ip
}

# Security groups
output "nat_security_group_id" {
  value = aws_security_group.nat_sg.id
}

output "dns_security_group_id" {
  value = aws_security_group.dns_sg.id
}

# to verify association
output "dhcp_options_id" {
  value = aws_vpc_dhcp_options.this.id
}

# Private route table 
output "private_route_table_id" {
  value = aws_route_table.private.id
}
