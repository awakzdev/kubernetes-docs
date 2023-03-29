# EKS Terraform Module

This Terraform module provisions an Amazon EKS cluster and associated resources in your AWS account. 

1. Creates an IAM role for the VPC CNI IRSA, which is a Kubernetes addon that assigns IP addresses to nodes in the cluster.
2. Creates an IAM role for the Workload Identity Federation using the aws_iam_role data source. This is used to authenticate Kubernetes service accounts within the EKS cluster.
3. Configures the EKS cluster to have public endpoint access.
4. Installs the coredns, kube-proxy, and vpc-cni addons in the cluster.
5. Specifies the VPC ID, subnet IDs, and control plane subnet IDs to use for the EKS cluster.

## Fetching kubeconfig
Linux
```
export CLUSTER_NAME=<cluster-name>
export AWS_REGION=<region>

aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
```
Windows
```
set CLUSTER_NAME=<cluster-name>
set AWS_REGION=<region>

aws eks update-kubeconfig --name %CLUSTER_NAME% --region %AWS_REGION%
```

