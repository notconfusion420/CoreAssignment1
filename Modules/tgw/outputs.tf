output "id" {
  description = "Transit Gateway ID"
  value       = aws_ec2_transit_gateway.this.id
}

output "route_table_id" {
  description = "Transit Gateway Route Table ID"
  value       = aws_ec2_transit_gateway_route_table.this.id
}
