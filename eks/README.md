# EKS on Terraform

This Terraform repository provisions an Amazon EKS cluster and associated resources in your AWS account. 

1. Creates an IAM role for the VPC CNI IRSA, which is a Kubernetes addon that assigns IP addresses to nodes in the cluster.
2. Creates an IAM role for the Workload Identity Federation using the aws_iam_role data source. This is used to authenticate Kubernetes service accounts within the EKS cluster.
3. Configures the EKS cluster to have public endpoint access.
4. Installs the coredns, kube-proxy, and vpc-cni addons in the cluster.
5. Specifies the VPC ID, subnet IDs, and control plane subnet IDs to use for the EKS cluster.
6. Installs the AWS ALB Ingress controllers.
7. Automatically configures IAM permisions and creates a Kubernets SA for AWS ALB Ingress Controller.

## Fetching kubeconfig
Linux
```
export CLUSTER_NAME=dev-eks
export AWS_REGION=eu-central-1

aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
```
Windows
```
$Env:CLUSTER_NAME="dev-eks"
$Env:AWS_REGION="eu-central-1"

aws eks update-kubeconfig --name $Env:CLUSTER_NAME --region $Env:AWS_REGION
```
