variable "name_prefix" {
  type        = string
  description = "Naming prefix for Resources"
}

variable "aws_iam_role" {
  type        = string
  description = "Workload Identity Federation Role"
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