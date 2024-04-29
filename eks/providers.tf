terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.12" # 5.12 Required for region 'il-central-1' (Tel-Aviv)
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
