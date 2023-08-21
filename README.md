# Kubernetes Infrastructure stack

This repository contains Terraform code to install a GKE / EKS cluster, with additional information on the installations process of externaldns and ingress-nginx secured by cert-manager (let's-encrypt) and more.

## Requirements
- [Terraform 0.12 or later](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- [GCloud CLI for GKE](https://cloud.google.com/sdk/docs/install)
- [AWS CLI for EKS](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Helm v3](https://helm.sh/docs/helm/helm_install/)

## Overview
- [ExternalDNS](#externaldns)
- [Cert-Manager (Lets-encrypt)](#certificate-manager)
- [NGINX-Ingress](#nginx-ingress)
- [EKS AWS Load Balancer Ingress](https://github.com/awakzdev/kubernetes-stack/tree/main/eks)
- [GKE Ingress Identity-Aware-Proxy-SSO](https://github.com/awakzdev/kubernetes-stack/tree/main/gke/iap)
- [GKE Cloud-SQL-Proxy](https://github.com/awakzdev/kubernetes-stack/tree/main/gke/sql-proxy)

## ExternalDNS
### 🌐 Overview 

**ExternalDNS** integrates with Kubernetes to automatically manage your DNS records. Here's how it works:

1. **Resource Retrieval**: It fetches resources like Services, Ingresses, and more from the Kubernetes API to determine the desired set of DNS records.
2. **DNS Configuration**, Not Hosting: Unlike KubeDNS, ExternalDNS isn't a DNS server. Instead, it configures third-party DNS providers such as AWS Route 53, Google Cloud DNS, and others.
3. **Provider Agnostic**: With ExternalDNS, you can control DNS records dynamically using Kubernetes resources, no matter which DNS provider you're working with.

🔍 For a deeper dive into ExternalDNS, check out the [FAQ](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/faq.md), where you'll find answers to key questions and concepts.

⚠️ Note
- 📌 EKS Focused: The upcoming External-DNS section is tailored specifically for EKS (Amazon Elastic Kubernetes Service).
- 📌 Other Kubernetes Providers: If you're using a Kubernetes provider other than EKS, please [refer to the official documentation.](https://github.com/kubernetes-sigs/external-dns)

### Installation 
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

**When installation is complete please review logs from your newly created pod to see if everything was set correctly.**

For more information about configuring and using the ExternalDNS chart, please refer to the [ExternalDNS documentation](https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns).

## Certificate manager
### 📜 Overview 
**Certificate Manager** simplifies the process of obtaining, renewing and using certificates.

It supports issuing certificates from a variety of sources:
- 🟢 Let's Encrypt (ACME)
- 🔑 HashiCorp Vault
- ☁️ Venafi TPP / TLS Protect Cloud
- 🌐 Local in-cluster issuance

Certmanager also ensures certificates remain valid and up to date, attempting to renew certificates at an appropriate time before expiry to reduce the risk of outages and remove toil.

![cert-manager](https://user-images.githubusercontent.com/96201125/218077336-ca9ad9c3-c1cf-422a-a65b-f3d342127f63.svg)

<hr>

### Installation
#### 1. Run the following command to install the cert-manager yaml:
```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml
```

For more information on cert-manager, please refer to the [cert-manager documentation](https://cert-manager.io/docs/installation/)

#### 2. Create a `ClusterIssuer`:
```
kubectl apply -f cluster-issuer.yaml
```
  
**Note: We have to make sure the 'class' section under `cluster-issuer.yaml` matches our ingressclass name. by default it is set to nginx.** (To find your ingressclass name run - `kubectl get ingressclass`)

For more information on the installation of cert-manager, visit https://cert-manager.io/docs/.

## NGINX Ingress
### 📜Overview

NGINX Ingress enhances your Kubernetes ecosystem by offering functionalities such as load balancing, SSL termination, and name-based virtual hosting. At its core, Ingress focuses on:

1. **Routing**: Directs external HTTP and HTTPS routes to internal cluster services, guided by the Ingress resource's rules.

2. **Examples in Action**:

![ingress](https://user-images.githubusercontent.com/96201125/218079432-176adbaf-31e8-4c13-910b-3f15799dfb59.svg)

In the illustration above, the Ingress routes all traffic to a single service.

3. **Extended Configurations**: Beyond basic routing, Ingress can:
- Provide externally-reachable URLs for services
- Load balance incoming traffic
- Terminate SSL/TLS connections
- Offer name-based virtual hosting
4. **Ingress Controller**: This entity ensures the Ingress' promises are kept, usually with a load balancer. It can also set up edge routers or additional frontends to manage incoming traffic.

5. **Protocols & Ports**: Ingress primarily deals with HTTP and HTTPS. For exposing other services and protocols, you'll likely use Service.Type=NodePort or Service.Type=LoadBalancer.

[🔍 Dive deeper into the world of Ingress with the official Kubernetes documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)

<hr>

### Installation
1. Add the helm chart
```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update  
```
2. Install the chart
```
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace
```

3. Create a deployment for Nginx:
```
kubectl create deploy nginx --image nginx
```

4. Expose the Nginx deployment:
We're gonna set this as ClusterIP to only receive communicating from inside the cluster while our ingress exposes our application.
```
kubectl expose deployment nginx --port 80
```

5. Apply the ingress YAML file:
- This ingress structure may be applied for different services if needed. You may edit and reuse for different services.
- The ingress might vary depending on the Kubernetes provider you are using.
```
kubectl apply -f ingress.yaml
```

#### To check the status of your certificates run the following command:
```
kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges --all-namespaces
```

For more information about the ingress-nginx installation, please refer to the [getting started documententation](https://kubernetes.github.io/ingress-nginx/deploy/)

# Feedback and Contributions
Feedback is welcomed, issues, and pull requests! If you have any suggestions or find any bugs, please open an issue on my GitHub repository.
