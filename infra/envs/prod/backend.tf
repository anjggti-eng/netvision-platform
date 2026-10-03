terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Backend parcial: preenchido em `terraform init -backend-config=backend.hcl`
  # (bucket criado por infra/bootstrap).
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "netvision-platform"
      ManagedBy   = "terraform"
      Environment = "prod"
    }
  }
}
