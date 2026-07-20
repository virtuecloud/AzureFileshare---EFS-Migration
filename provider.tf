terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11"
    }
  }

  # Recommended for prod: move to S3 backend with DynamoDB locking.
  # backend "s3" {
  #   bucket         = "vision-bank-terraform-state"
  #   key            = "datasync-nfs-efs/terraform.tfstate"
  #   region         = "eu-central-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}
