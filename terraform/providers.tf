# ---------------------------------------------------------------------------
# Provider configuration
# Using LocalStack to simulate AWS locally — zero cost, zero AWS account needed
# In production: remove the endpoints block and set real AWS credentials
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # LocalStack endpoint — simulates AWS APIs locally
  endpoints {
    ec2 = "http://localhost:4566"
    s3  = "http://localhost:4566"
    iam = "http://localhost:4566"
  }

  # LocalStack doesn't need real credentials
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}