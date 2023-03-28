# VPC module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.12.0"

  name               = "Infrastructure VPC"
  cidr               = var.vpc_cidr
  azs                = var.vpc_availability_zones
  private_subnets    = [var.private_primary_subnet_cidr, var.private_secondary_subnet_cidr]
  public_subnets     = [var.public_primary_subnet_cidr, var.public_secondary_subnet_cidr]
  enable_nat_gateway = true
}