# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "FinalProject"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# Data source to get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}
