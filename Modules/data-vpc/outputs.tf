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
    