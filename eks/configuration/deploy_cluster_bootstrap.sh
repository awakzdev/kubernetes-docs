aws eks update-kubeconfig --name apple-eks-cluster --region il-central-1

route53_zone=cclab.cloud-castles.com

kubectl apply -f namespaces.yaml
kubectl apply -f serviceaccounts.yaml

helm repo add eks https://aws.github.io/eks-charts
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo add jetstack https://charts.jetstack.io
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller --set clusterName=apple-eks-cluster -n kube-system --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
helm upgrade --install external-dns external-dns/external-dns --version 1.14.4 --namespace external-dns --set serviceAccount.create=false --set serviceAccount.name=external-dns --set domainFilters[0]=$route53_zone
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.14.4 --set installCRDs=true --set serviceAccount.create=false --set serviceAccount.name=cert-manager
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx