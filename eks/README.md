# EKS Terraform Module

This Terraform module provisions an Amazon EKS cluster and associated resources in your AWS account. 

1. Creates an IAM role for the VPC CNI IRSA, which is a Kubernetes addon that assigns IP addresses to nodes in the cluster.
2. Creates an IAM role for the Workload Identity Federation using the aws_iam_role data source. This is used to authenticate Kubernetes service accounts within the EKS cluster.
3. Configures the EKS cluster to have public endpoint access.
4. Installs the coredns, kube-proxy, and vpc-cni addons in the cluster.
5. Specifies the VPC ID, subnet IDs, and control plane subnet IDs to use for the EKS cluster.
6. Configures all Resources / IAM Permissions needed for an AWS Load Balancer Controller as an Ingress.

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

## Installing the AWS Load Balancer Controller add-on
The AWS Load Balancer Controller manages AWS Elastic Load Balancers for a Kubernetes cluster. The controller provisions the following resources:

- An AWS Application Load Balancer (ALB) when you create a Kubernetes Ingress.
- An AWS Network Load Balancer (NLB) when you create a Kubernetes service of type LoadBalancer.

1. Apply the `aws-ingress.tf`
2. Create an example ingress using the `ingress.yaml

By now you should have an AWS Application Load Balancer serving an Ingress on as HTTPS
