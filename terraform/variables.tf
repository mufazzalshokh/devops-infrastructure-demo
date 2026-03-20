# ---------------------------------------------------------------------------
# Input variables — all infrastructure parameters are configurable
# Never hardcode values that differ between environments
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Deployment environment (development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
  default     = "devops-demo"
}

variable "instance_type" {
  description = "EC2 instance type for the application server"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Amazon Machine Image ID (Ubuntu 22.04 LTS)"
  type        = string
  default     = "ami-0c1c30571d2dae5be"  # Ubuntu 22.04 eu-west-1
}

variable "s3_bucket_name" {
  description = "S3 bucket for application artifacts and logs"
  type        = string
  default     = "devops-demo-artifacts"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into EC2 instance"
  type        = string
  default     = "0.0.0.0/0"  # Restrict in production!
}