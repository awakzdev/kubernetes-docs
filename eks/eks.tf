# VPC CNI IRSA Role module (kubernetes addon)
# This resource is required to assign IP address to the nodes, otherwise they wont be attached.
module "vpc_cni_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "vpc-cni"

  attach_vpc_cni_policy = true # this is required to attach nodes to eks
  vpc_cni_enable_ipv4   = true # this is required to attach nodes to eks

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

# IAM Role for 'Workload Identity Federation'
data "aws_iam_role" "workload_identity_federation" {
  name = var.aws_iam_role
}

# EKS module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.name_prefix}-eks"
  cluster_version = "1.24"

  # Private EKS
  cluster_endpoint_private_access = false
  # Public EKS
  cluster_endpoint_public_access  = true

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

  # Self Managed Node Group(s)
  self_managed_node_group_defaults = {
    instance_type                          = "m6i.large"
    update_launch_template_default_version = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  self_managed_node_groups = {
    one = {
      name         = "mixed-1"
      max_size     = 5
      desired_size = 2

      use_mixed_instances_policy = true
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_base_capacity                  = 0
          on_demand_percentage_above_base_capacity = 10
          spot_allocation_strategy                 = "capacity-optimized"
        }

        override = [
          {
            instance_type     = "m5.large"
            weighted_capacity = "1"
          },
          {
            instance_type     = "m6i.large"
            weighted_capacity = "2"
          },
        ]
      }
    }
  }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types             = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
    iam_role_attach_cni_policy = true
    capacity_type              = "ON_DEMAND"
  }

  eks_managed_node_groups = {
    blue = {}
    green = {
      min_size     = 1
      max_size     = 10
      desired_size = 1

      instance_types = ["t3.large"]
    }
  }

  # Fargate Profile(s)
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "default"
        }
      ]
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam:${data.aws_caller_identity.current.account_id}:role/${data.aws_iam_role.workload_identity_federation.arn}"
      username = "sso-admin:{{SessionName}}"
      groups   = ["system:masters"]
    },
  ]

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}