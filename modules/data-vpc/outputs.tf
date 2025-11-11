output "vpc_id" {
  value = aws_vpc.this.id
}

output "admin_instance_sg_id" {
  value = aws_security_group.admin_ec2_sg.id
}

output "data_private_subnet_id" {
  value = aws_subnet.private_a.id
}
