# Google Kubernetes Engine - ingress-nginx with externaldns and cert-manager

This repository contains Terraform code to install a Google Kubernetes Engine (GKE) cluster, with additional installations of externaldns and ingress-nginx secured by cert-manager (letsencrypt).

## Requirements
- Terraform 0.12 or later
- Google Cloud Platform account with permissions to create a GKE cluster and necessary firewall rules
- Domain name to use with externaldns
- [GCloud CLI](https://cloud.google.com/sdk/docs/install)
- [Helm v3](https://helm.sh/docs/helm/helm_install/)

## Terraform GKE Installation

### 1. Clone this repository:
```
git clone https://github.com/Cloud-Castles/gke-externaldns.git
```

### 2. Change into the repository directory:
```
cd gke-externaldns
```

### 3. Initialize Terraform:
```
terraform init
```

### 4. Create a terraform.tfvars file to store your GCP project and region variables:
```
cat <<EOF > terraform.tfvars
gcp_project = "<your-gcp-project-name>"
gcp_region = "<your-gcp-region>"
EOF
```

### 5. Apply the Terraform code:
```
terraform apply
```

For more information on installing GKE with Terraform, please refer to the [Terraform GKE documentation.](https://developer.hashicorp.com/terraform/tutorials/kubernetes/gke).

## ExternalDNS Installation

Before installing ExternalDNS, we need to set up Route53 as our DNS method. In this case, we'll use static credentials to grant ExternalDNS access to Route53.

**If you are working with a different DNS provider please skip to step 5.**

In this method, the policy is attached to an IAM user, and the credentials secrets for the IAM user are then made available using a Kubernetes secret.

This method is not the preferred method as the secrets in the credential file could be copied and used by an unauthorized threat actor. However, if the Kubernetes cluster is not hosted on AWS, it may be the only method available. Given this situation, it is important to limit the associated privileges to just minimal required privileges, i.e. read-write access to Route53, and not used a credentials file that has extra privileges beyond what is required.

### 1. Create IAM Policy
Create an IAM policy with the following content:
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
```

Using the AWS CLI, the policy can be installed by running the following command (with the policy saved as policy.json):
```
aws iam create-policy --policy-name "AllowExternalDNSUpdates" --policy-document file://policy.json
```

### 2. Create IAM User and Attach Policy

To create an IAM user and attach the policy, run the following commands:
```
# create IAM user
aws iam create-user --user-name "externaldns"

# attach policy arn created earlier to IAM user
aws iam attach-user-policy --user-name "externaldns" --policy-arn $POLICY_ARN
```

### 3. Create Static Credentials

To create the static credentials, run the following commands:
```
SECRET_ACCESS_KEY=$(aws iam create-access-key --user-name "externaldns")
cat <<-EOF > ./credentials

[default]
aws_access_key_id = $(echo $SECRET_ACCESS_KEY | jq -r '.AccessKey.AccessKeyId')
aws_secret_access_key = $(echo $SECRET_ACCESS_KEY | jq -r '.AccessKey.SecretAccessKey')
EOF
```

### 4. Create Kubernetes Secret from Credentials

To create the Kubernetes secret from the credentials, run the following command:
```
kubectl create secret generic external-dns \
  --namespace ${EXTERNALDNS_NS:-"default"} --from-file ./credentials
```

Note: The value of EXTERNALDNS_NS should be set to the namespace in which ExternalDNS will be installed. The default value is "default".

### 5. Navigate to the charts folder:
```
cd charts
```

### 6. Add the external-dns repository:
```
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
```

### 7. Adding credentials to externaldns-values.yaml
Setting credentials by scrolling to the bottom of the file and changing the data section L137. (Credentials were generated on step 3)

### 8. Install and upgrade external-dns using the values file:
```
helm upgrade --install external-dns external-dns/external-dns -f externaldns-values.yaml
```

**Optional - When installation is complete check to see credentials were set under 'env' section for our new deployment `my-release-external-dns`**
```
kubectl edit deployments
```

For more information on configuring and using the external-dns chart, please refer to the [external-dns chart documentation](https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns).

## Installation of Cert-Manager

### 1. Run the following command to install the cert-manager yaml:
```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml
```

For more information on cert-manager, please refer to the [cert-manager installation page](https://cert-manager.io/docs/installation/)

### 2. Navigate to the cert-manager folder and install using:
```
kubectl apply -f clusterissuer.yaml
```

**Note: We have to make sure the 'class' section under clusterissuer.yaml matches our ingressclass name. by default it is set to nginx but it is not always the case. In addition to that we'll have to create a seperate clusterissuer for every individual ingress as only ingress per secret is allowed.**

To find your ingressclass name run - `kubectl get ingressclass`

For more information on the installation of cert-manager, visit https://cert-manager.io/docs/.

## Installing ingress-nginx

### 1. To install ingress-nginx, run the following command:
```
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

For more information about the ingress-nginx, please refer to the [getting started documententation](https://kubernetes.github.io/ingress-nginx/deploy/)

### 2. Create a deployment for Nginx:
```
kubectl create deploy nginx --image nginx
```

### 3. Expose the Nginx deployment:
We're gonna set this as ClusterIP to only receive communicating from inside the cluster while our ingress exposes our application.
```
kubectl expose deployment nginx --port 80
```

### 4. Apply the Nginx Ingress YAML file:

Note: Make sure you are in the root directory.
```
kubectl apply -f ingress.yaml
```

This ingress structure may be applied for different services if needed. You may edit and reuse for different services.

### 5. Optional - To check the status of your certificates, run the following command:
```
kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges --all-namespaces
```
