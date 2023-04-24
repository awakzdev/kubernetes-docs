# Setting ExternalDNS Ingress-NGINX Cert-manager (Let's-Encrypt)

This repository contains Terraform code to install a Google Kubernetes Engine (GKE) cluster, with additional information on the installations process of externaldns and ingress-nginx secured by cert-manager (letsencrypt).

## Requirements
- Google Cloud Platform account with permissions to create a GKE cluster and necessary firewall rules
- Domain name to use with Ingress
- [Terraform 0.12 or later](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- [GCloud CLI](https://cloud.google.com/sdk/docs/install)
- [Helm v3](https://helm.sh/docs/helm/helm_install/)


## Overview
- [Terraform Kubernetes Provisioning (GKE)](#terraform-gke-installation)
- [ExternalDNS](#externaldns)
- [Cert-Manager (Lets-encrypt)](#cert-manager)
- [Ingress-NGINX](#ingress-nginx)


## Terraform GKE Installation

#### 1. Clone this repository:
```
git clone https://github.com/awakzdev/kubernetes-stack.git
```

#### 2. Change into the repository directory:
```
cd kubernetes-stack
```

#### 3. Initialize Terraform:
```
terraform init
```

#### 4. Create a terraform.tfvars file to store your GCP project and region variables:
```
cat <<EOF > terraform.tfvars
gcp_project = "<your-gcp-project-name>"
gcp_region = "<your-gcp-region>"
EOF
```

#### 5. Apply the Terraform code:
```
terraform apply
```

For more information on installing GKE with Terraform, please refer to the [Terraform GKE documentation.](https://developer.hashicorp.com/terraform/tutorials/kubernetes/gke).

## ExternalDNS

#### What it does? 

It retrieves a list of resources (Services, Ingresses, etc.) from the Kubernetes API to determine a desired list of DNS records. Unlike KubeDNS, however, it's not a DNS server itself, but merely configures other DNS providers accordingly—e.g. AWS Route 53 or Google Cloud DNS.

In a broader sense, ExternalDNS allows you to control DNS records dynamically via Kubernetes resources in a DNS provider-agnostic way.

The [FAQ](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/faq.md) contains additional information and addresses several questions about key concepts of ExternalDNS.

<image src="https://user-images.githubusercontent.com/96201125/218077591-25628816-337a-46e3-a198-cf5facf542e8.png" width=300>

<hr>

**If you are working with a different DNS provider please skip to step 5.**

Before installing ExternalDNS, we need to set up Route53 as our DNS method. In this case, we'll use static credentials to grant ExternalDNS access to Route53.

In this method, the policy is attached to an IAM user, and the credentials secrets for the IAM user are then made available using a Kubernetes secret.

This method is not the preferred method as the secrets in the credential file could be copied and used by an unauthorized threat actor. However, if the Kubernetes cluster is not hosted on AWS, it may be the only method available. Given this situation, it is important to limit the associated privileges to just minimal required privileges, i.e. read-write access to Route53, and not used a credentials file that has extra privileges beyond what is required.

#### 1. Create IAM Policy
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

#### 2. Create IAM User and Attach Policy
```
# create IAM user
aws iam create-user --user-name "externaldns"

# attach policy arn created earlier to IAM user
aws iam attach-user-policy --user-name "externaldns" --policy-arn $POLICY_ARN
```

#### 3. Create Static Credentials
```
SECRET_ACCESS_KEY=$(aws iam create-access-key --user-name "externaldns")
cat <<-EOF > ./credentials

[default]
aws_access_key_id = $(echo $SECRET_ACCESS_KEY | jq -r '.AccessKey.AccessKeyId')
aws_secret_access_key = $(echo $SECRET_ACCESS_KEY | jq -r '.AccessKey.SecretAccessKey')
EOF
```

#### 4. Add the external-dns repository:
```
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
```

#### 5. Adding credentials to values.yaml
[Credentials were generated on step 3](#3-create-static-credentials).
```
Setting credentials by editing the data section.
  data:
    credentials: |
      [default]
      aws_access_key_id = <CHANGE THIS>
      aws_secret_access_key = <CHANGE THIS>

Change the domain name under `domainFilters` to match your domain name.
domainFilters: [foo.domain.com]
```

#### 6. Install and upgrade external-dns using the values file:
```
helm upgrade --install external-dns external-dns/external-dns -f values.yaml
```

**When installation is complete check to see credentials are currently set by checking logs on your newly created pod.**

For more information on configuring and using the external-dns chart, please refer to the [external-dns chart documentation](https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns).

## Cert-Manager

### What it does? 

cert-manager adds certificates and certificate issuers as resource types in Kubernetes clusters, and simplifies the process of obtaining, renewing and using those certificates.

It supports issuing certificates from a variety of sources, including Let's Encrypt (ACME), HashiCorp Vault, and Venafi TPP / TLS Protect Cloud, as well as local in-cluster issuance.

cert-manager also ensures certificates remain valid and up to date, attempting to renew certificates at an appropriate time before expiry to reduce the risk of outages and remove toil.

![cert-manager](https://user-images.githubusercontent.com/96201125/218077336-ca9ad9c3-c1cf-422a-a65b-f3d342127f63.svg)


<hr>

#### 1. Run the following command to install the cert-manager yaml:
```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml
```

For more information on cert-manager, please refer to the [cert-manager installation page](https://cert-manager.io/docs/installation/)

#### 2. Navigate to the cert-manager folder and install using:
```
cd cert-manager
kubectl apply -f cluster-issuer.yaml
```
**If the above step fails please repeat step 1.**
 
**Note: We have to make sure the 'class' section under cluster-issuer.yaml matches our ingressclass name. by default it is set to nginx but it is not always the case.** (To find your ingressclass name run - `kubectl get ingressclass`)

For more information on the installation of cert-manager, visit https://cert-manager.io/docs/.

## Ingress-NGINX

### Overview

Ingress may provide load balancing, SSL termination and name-based virtual hosting for Kubernetes using NGINX.
Ingress exposes HTTP and HTTPS routes from outside the cluster to services within the cluster. Traffic routing is controlled by rules defined on the Ingress resource.

Here is a simple example where an Ingress sends all its traffic to one Service:
![ingress](https://user-images.githubusercontent.com/96201125/218079432-176adbaf-31e8-4c13-910b-3f15799dfb59.svg)

Figure. Ingress

An Ingress may be configured to give Services externally-reachable URLs, load balance traffic, terminate SSL / TLS, and offer name-based virtual hosting. An Ingress controller is responsible for fulfilling the Ingress, usually with a load balancer, though it may also configure your edge router or additional frontends to help handle the traffic.

An Ingress does not expose arbitrary ports or protocols. Exposing services other than HTTP and HTTPS to the internet typically uses a service of type Service.Type=NodePort or Service.Type=LoadBalancer.

[Learn more about Ingress on the main Kubernetes documentation site.](https://kubernetes.io/docs/concepts/services-networking/ingress/)

<hr>

#### 1. To install ingress-nginx, run the following command:
Add the helm chart
```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update  
```
Install the chart
```
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace
```

For more information about the ingress-nginx installation, please refer to the [getting started documententation](https://kubernetes.github.io/ingress-nginx/deploy/)

#### 2. Create a deployment for Nginx:
```
kubectl create deploy nginx --image nginx
```

#### 3. Expose the Nginx deployment:
We're gonna set this as ClusterIP to only receive communicating from inside the cluster while our ingress exposes our application.
```
kubectl expose deployment nginx --port 80
```

#### 4. Apply the ingress YAML file:

Note: This ingress structure may be applied for different services if needed. You may edit and reuse for different services.
```
cd ingress
kubectl apply -f ingress.yaml
```

#### To check the status of your certificates run the following command:
```
kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges --all-namespaces
```

# License
[Apache License 2.0](https://github.com/awakzdev/kubernetes-stack/blob/main/LICENSE)
