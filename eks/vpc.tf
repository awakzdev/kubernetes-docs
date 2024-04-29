##########################
## VPC module
##########################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.7.1"

  name               = "${var.name_prefix} VPC"
  cidr               = var.vpc_cidr
  azs                = var.vpc_availability_zones
  private_subnets    = [var.private_primary_subnet_cidr, var.private_secondary_subnet_cidr]
  public_subnets     = [var.public_primary_subnet_cidr, var.public_secondary_subnet_cidr]
  enable_nat_gateway = true

  tags = {
    Terraform                                 = "true"
    Environment                               = var.environment
    "kubernetes.io/role/elb"                  = 1
    "kubernetes.io/cluster/apple-eks-cluster" = "owned"
  }
}