output "vpc_id" {
  value = aws_vpc.this.id
}

output "dmz_subnet_id" {
  value = aws_subnet.dmz_a.id
}

output "app_subnet_id" {
  value = aws_subnet.app_a.id
}