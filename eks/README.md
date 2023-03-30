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

### Prerequisites
- An existing Amazon EKS cluster. To deploy one, see Getting started with Amazon EKS.
- An existing AWS Identity and Access Management (IAM) OpenID Connect (OIDC) provider for your cluster. To determine whether you already have one, or to create one, see Creating an IAM OIDC provider for your cluster.
- If your cluster is 1.21 or later, make sure that your Amazon VPC CNI plugin for Kubernetes, kube-proxy, and CoreDNS add-ons are at the minimum versions listed in Service account tokens.
- Familiarity with AWS Elastic Load Balancing. For more information, see the Elastic Load Balancing User Guide.
- Familiarity with Kubernetes service and ingress resources.

###  **To deploy the AWS Load Balancer Controller to an Amazon EKS cluster**
In the following steps, replace the `example values` with your own values.

1. Create an IAM policy.

    a. Download an IAM policy for the AWS Load Balancer Controller that allows it to make calls to AWS APIs on your behalf.

    -  AWS GovCloud (US-East) or AWS GovCloud (US-West) AWS Regions
        ```
        curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy_us-gov.json
        ```
    - All other AWS Regions
        ```
        curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json
        ```
    b. Create an IAM policy using the policy downloaded in the previous step. If you downloaded iam_policy_us-gov.json, change iam_policy.json to iam_policy_us-gov.json before running the command.
    ```
    aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file://iam_policy.json
    ```
2. Create an IAM role. Create a Kubernetes service account named aws-load-balancer-controller in the kube-system namespace for the AWS Load Balancer Controller and annotate the Kubernetes service account with the name of the IAM role.

    You can use eksctl or the AWS CLI and kubectl to create the IAM role and Kubernetes service account.

    **eksctl**

    ```
    eksctl create iamserviceaccount \
    --cluster=my-cluster \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --attach-policy-arn=arn:aws:iam::111122223333:policy/   AWSLoadBalancerControllerIAMPolicy \
    --approve
    ```
    **AWS CLI and kubectl**

    a. Retrieve your cluster's OIDC provider ID and store it in a variable.
    ```
    oidc_id=$(aws eks describe-cluster --name my-cluster --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
    ```
    b. Determine whether an IAM OIDC provider with your cluster's ID is already in your account.
    ```
    aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4
    ```
    If output is returned, then you already have an IAM OIDC provider for your cluster. If no output is returned, then you must create an IAM OIDC provider for your cluster. For more information, see [Creating an IAM OIDC provider for your cluster.](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)

    c. Copy the following contents to your device. Replace `111122223333` with your account ID. Replace region-code with the AWS Region that your cluster is in.. Replace `EXAMPLED539D4633E53DE1B71EXAMPLE` with the output returned in the previous step. If your cluster is in the AWS GovCloud (US-East) or AWS GovCloud (US-West) AWS Regions, then replace `arn:aws:` with `arn:aws-us-gov:`. After replacing the text, run the modified command to create the load-balancer-role-trust-policy.json file.
    ```
    cat >load-balancer-role-trust-policy.json <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Federated": "arn:aws:iam::111122223333:oidc-provider/oidc.eks.region-code.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
                },
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        "oidc.eks.region-code.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud": "sts.amazonaws.com",
                        "oidc.eks.region-code.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
                    }
                }
            }
        ]
    }
    EOF
    ```
    d. Create the IAM role.
    ```
    aws iam create-role \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --assume-role-policy-document file://"load-balancer-role-trust-policy.json"
    ```
    e. Attach the required Amazon EKS managed IAM policy to the IAM role. Replace `111122223333` with your account ID.
    ```
    aws iam attach-role-policy \
    --policy-arn arn:aws:iam::111122223333:policy/AWSLoadBalancerControllerIAMPolicy \
    --role-name AmazonEKSLoadBalancerControllerRole
    ```
    f. Copy the following contents to your device. Replace `111122223333` with your account ID. If your cluster is in the AWS GovCloud (US-East) or AWS GovCloud (US-West) AWS Regions, then replace `arn:aws:` with `arn:aws-us-gov:`. After replacing the text, run the modified command to create the `aws-load-balancer-controller-service-account.yaml` file.
    ```
    cat >aws-load-balancer-controller-service-account.yaml <<EOF
    apiVersion: v1
    kind: ServiceAccount
    metadata:
    labels:
        app.kubernetes.io/component: controller
        app.kubernetes.io/name: aws-load-balancer-controller
    name: aws-load-balancer-controller
    namespace: kube-system
    annotations:
        eks.amazonaws.com/role-arn: arn:aws:iam::111122223333:role/AmazonEKSLoadBalancerControllerRole
    EOF
    ```
    g. Create the Kubernetes service account on your cluster. The Kubernetes service account named `aws-load-balancer-controller` is annotated with the IAM role that you created named `AmazonEKSLoadBalancerControllerRole`.
    ```
    kubectl apply -f aws-load-balancer-controller-service-account.yaml
    ```

3. Install the AWS Load Balancer Controller using Helm V3 or later.

    a. Add the eks-charts repository.
    ```
    helm repo add eks https://aws.github.io/eks-charts
    ```
    b. Update your local repo to make sure that you have the most recent charts.
    ```
    helm repo update
    ```
    c. Install the AWS Load Balancer Controller. If you're deploying the controller to Amazon EC2 nodes that have restricted access to the Amazon EC2 instance metadata service (IMDS), or if you're deploying to Fargate, then add the following flags to the helm command that follows:

    `--set region=region-code`

    `--set vpcId=vpc-xxxxxxxx`

    Replace `my-cluster` with the name of your cluster. In the following command, `aws-load-balancer-controller` is the Kubernetes service account that you created in a previous step.
    ```
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=my-cluster \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller 
    ```

    ## **Important**

    The deployed chart doesn't receive security updates automatically. You need to manually `upgrade` to a newer chart when it becomes available. When upgrading, change install to upgrade in the previous command, but run the following command to install the `TargetGroupBinding` custom resource definitions before running the previous command.
    ```
    kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
    ```
4. Verify that the controller is installed.
```
kubectl get deployment -n kube-system aws-load-balancer-controller
```
The example output is as follows.
```
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
aws-load-balancer-controller   2/2     2            2           84s
```