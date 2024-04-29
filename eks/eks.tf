#############################################
# VPC CNI IRSA Role module (kubernetes addon)
#############################################
module "vpc_cni_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "vpc-cni"

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}


#############################################
# EKS module
#############################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.name_prefix}-eks-cluster"
  cluster_version = "1.29" # Latest as of 4/18/2024

  cluster_endpoint_public_access = true
  # Private endpoint requires access from within the VPC and has to be setup either via a bastion or Cloud9 (Web IDE for EKS management)
  cluster_endpoint_private_access = false


  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # VPC module outputs
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    iam_role_attach_cni_policy             = true
    update_launch_template_default_version = true

    iam_role_additional_policies = {
      # The below policy allows automated patching and data collection for EC2 instances.
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  eks_managed_node_groups = {

    # Infrastructure nodes
    infra = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.small"]

      tags = {
        Name = "eks-${var.name_prefix}-cluster-infra"
      }
    }

    # Application nodes
    application = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.small"]

      tags = {
        Name = "eks-${var.name_prefix}-cluster-application"
      }
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  # enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}


#####################################################################################################
# Access Entry
# The section below grants EKS admin privilege to multiple AWS Account ID's set by a variable (list)
#####################################################################################################
resource "aws_eks_access_entry" "admin_access_entry" {
  for_each      = toset(var.eks_admins)
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::${each.value}:role/${var.principal_arn}"
  type          = "STANDARD"
  
  tags          = {
    "Environment" = var.environment
    "Terraform"   = "true"
  }

  tags_all = {
    "Environment" = var.environment
    "Terraform"   = "true"
  }
}

resource "aws_eks_access_policy_association" "admin_policy_association" {
  for_each      = toset(var.eks_admins)
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::${each.value}:role/${var.principal_arn}"

  access_scope {
    type = "cluster"
  }
}
