# EKS Terraform Module

This Terraform module provisions an Amazon EKS cluster and associated resources in your AWS account. 

## Fetching kubeconfig
Linux
```
export CLUSTER_NAME=dev-eks
export AWS_REGION=us-east-1

aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
```
Windows
```
set CLUSTER_NAME=dev-eks
set AWS_REGION=us-east-1

aws eks update-kubeconfig --name %CLUSTER_NAME% --region %AWS_REGION%
```

