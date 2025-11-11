output "public_ip" {
  value = aws_instance.this.public_ip
}

output "grafana_url" {
  value = "http://${aws_instance.this.public_ip}:3000"
}

output "prometheus_url" {
  value = "http://${aws_instance.this.public_ip}:9090"
}

output "sg_id" {
  description = "Security group ID of the monitoring instance"
  value       = aws_security_group.this.id
}

output "private_ip" {
  description = "Private IP of the monitoring instance"
  value       = aws_instance.this.private_ip
}
