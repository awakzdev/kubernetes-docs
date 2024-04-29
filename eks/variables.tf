variable "name_prefix" {
  type        = string
  description = "Naming prefix for Resources"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "aws_region" {
  type        = string
  description = "Region for AWS Resources"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "vpc_availability_zones" {
  type        = list(string)
  description = "List of availability zones for the VPC"
}

variable "private_primary_subnet_cidr" {
  type        = string
  description = "CIDR block for the primary private subnet"
}

variable "private_secondary_subnet_cidr" {
  type        = string
  description = "CIDR block for the secondary private subnet"
}

variable "public_primary_subnet_cidr" {
  type        = string
  description = "CIDR block for the primary public subnet"
}

variable "public_secondary_subnet_cidr" {
  type        = string
  description = "CIDR block for the secondary public subnet"
}

variable "principal_arn" {
  # This value might change depending on the environment but here's a sample of what It might look like
  // "arn:aws:iam::000000:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_AdministratorAccess_000000"
  // The part after the `:/role` should be the value
  // You will be able to get the full value by setting `enable_cluster_creator_admin_permissions` to true on the EKS module
  // Access entry code (inside EKS.tf file) have to be commented in order to retrieve the value.
  description = "The ARN of the principal (user or role) that will have access to the EKS cluster"
  type        = string
}

variable "eks_admins" {
  type = list
  description = "A list of AWS account to grant EKS admin access to"
  default = []
}