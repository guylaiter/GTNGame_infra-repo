terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "guy-terraform-state-finalproject"
    key     = "eks/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}
