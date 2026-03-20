# ---------------------------------------------------------------------------
# Outputs — values exposed after terraform apply
# Useful for other systems, scripts, or CI/CD pipelines
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.api_server.id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.api_server.public_ip
}

output "s3_bucket_name" {
  description = "S3 artifacts bucket name"
  value       = aws_s3_bucket.artifacts.bucket
}

output "security_group_id" {
  description = "API security group ID"
  value       = aws_security_group.api.id
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}