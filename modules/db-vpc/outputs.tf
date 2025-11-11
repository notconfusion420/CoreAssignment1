output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_id" { value = aws_subnet.public_a.id }
output "db_subnet_ids" { value = [aws_subnet.db_a.id, aws_subnet.db_b.id] }
output "tgw_attachment_id" { value = aws_ec2_transit_gateway_vpc_attachment.this.id }
output "rds_endpoint" { value = aws_db_instance.this.endpoint }
output "redis_endpoint" { value = aws_elasticache_replication_group.redis.primary_endpoint_address }

output "s3_bucket_name" {
  value       = var.enable_s3 ? aws_s3_bucket.data[0].bucket : null
  description = "S3 bucket (if enabled)"
}

output "cloudfront_domain_name" {
  value       = var.enable_s3 && var.enable_cloudfront ? aws_cloudfront_distribution.this[0].domain_name : null
  description = "CloudFront domain (if enabled)"
}

output "dhcp_options_id" {
  value = aws_vpc_dhcp_options.dns.id
}