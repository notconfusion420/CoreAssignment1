output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_ids" {
  value = [aws_subnet.data_a.id, aws_subnet.data_b.id]
}

output "ec2_id" {
  value = aws_instance.data.id
}

output "tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.this.id
}

output "dhcp_options_id" {
  value = aws_vpc_dhcp_options.dns.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "s3_gateway_endpoint_id" {
  value = try(aws_vpc_endpoint.s3[0].id, null)
}

output "dynamodb_gateway_endpoint_id" {
  value = try(aws_vpc_endpoint.dynamodb[0].id, null)
}
