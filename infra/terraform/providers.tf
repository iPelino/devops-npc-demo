terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"

  # Backend configuration is commented out for initial setup.
  # Uncomment and configure after creating the S3 bucket and DynamoDB table.
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "devops-demo/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "your-terraform-lock-table"
  # }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "devops-demo"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
