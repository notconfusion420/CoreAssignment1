output "app_vpc_id" {
  value = aws_vpc.this.id
}

output "app_private_subnet_id" {
  value = aws_subnet.private_a.id
}

output "app_ec2_sg_id" {
  value = aws_security_group.app_ec2_sg.id
}
output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_id" {
  value = aws_subnet.private_a.id
}
