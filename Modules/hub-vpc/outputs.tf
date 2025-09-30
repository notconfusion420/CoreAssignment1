output "vpc_id"           { value = aws_vpc.this.id }
output "public_subnet_id" { value = aws_subnet.public_a.id }
output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}
output "resolver_inbound_ips" {
  value = [for ip in aws_route53_resolver_endpoint.inbound.ip_address : ip.ip]
}
output "resolver_outbound_ips" {
  value = [for ip in aws_route53_resolver_endpoint.outbound.ip_address : ip.ip]
}
output "tgw_attachment_id" { value = aws_ec2_transit_gateway_vpc_attachment.this.id }
