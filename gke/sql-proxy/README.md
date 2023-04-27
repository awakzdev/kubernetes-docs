## Setting up Cloud SQL Proxy on Kubernetes
This guide will help you set up Cloud SQL Proxy on Kubernetes to connect your applications running on Google Kubernetes Engine (GKE) to Cloud SQL instances using the Cloud SQL Proxy Operator.

### Prequisites
1. Make sure the user or service account has the Cloud SQL Client role, which authorizes a principal to connect to all Cloud SQL instances in a project.
- Go to the [IAM page](https://console.cloud.google.com/iam-admin/iam)
2. Enable the Cloud SQL Admin API.
- [Enable the API](https://console.cloud.google.com/apis/library/sqladmin.googleapis.com)
3. Install and initialize the gcloud CLI.
4. Cert-Manager Installed with CRDs configured.
```yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version "v1.9.1" \
  --create-namespace \
  --set global.leaderElection.namespace=cert-manager \
  --set installCRDs=true
```

### Install Cloud SQL Proxy Operator
1. Install the Cloud SQL Proxy Operator to your Kubernetes cluster
```yaml
kubectl apply -f https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy-operator/v0.3.0/cloud-sql-proxy-operator.yaml
```
2. Wait for the Cloud SQL Proxy Operator to start.
```yaml
kubectl rollout status deployment -n cloud-sql-proxy-operator-system cloud-sql-proxy-operator-controller-manager --timeout=90s
```
3. Confirm that the Cloud SQL Proxy Operator is installed and running:
```yaml
kubectl get pods -n cloud-sql-proxy-operator-system
```
Now, the Cloud SQL Proxy Operator is set up on your Kubernetes cluster, and you can connect your applications running on GKE to Cloud SQL instances using the Cloud SQL Proxy.

### Connect from Google Kubernetes Engine
1. Create a Secret object
You create the Secret objects by using the kubectl create secret command.

To create a database credentials Secret:

```yaml
kubectl create secret generic <YOUR-DB-SECRET> \
  --from-literal=username=<YOUR-DATABASE-USER> \
  --from-literal=password=<YOUR-DATABASE-PASSWORD> \
  --from-literal=database=<YOUR-DATABASE-NAME>
```

2. Enable the Cloud SQL Admin API
- [Enable the API](https://console.cloud.google.com/flows/enableapi?apiid=sqladmin&redirect=https://console.cloud.google.com&_ga=2.247787908.243039127.1682587924-1520538760.1676743235)

3. Configuring Workload Identity
If you are using Google Kubernetes Engine, the preferred method is to use GKE's Workload Identity feature. This method allows you to bind a Kubernetes Service Account (KSA) to a Google Service Account (GSA). The GSA will then be accessible to applications using the matching KSA.

A Google Service Account (GSA) is an IAM identity that represents your application in Google Cloud. In a similar fashion, a Kubernetes Service Account (KSA) is a an identity that represents your application in a Google Kubernetes Engine cluster.

Workload Identity binds a KSA to a GSA, causing any deployments with that KSA to authenticate as the GSA in their interactions with Google Cloud.
- [Enable Workload Identity for your cluster](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#enable_on_cluster)
- Typically, each application has its own identity, represented by a KSA and GSA pair. Create a KSA for your application by running `kubectl apply -f service-account.yaml:`
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: <YOUR-KSA-NAME> # TODO(developer): replace these values
```
- Enable the IAM binding between your **YOUR-GSA-NAME** and **YOUR-KSA-NAME:**
```yaml
gcloud iam service-accounts add-iam-policy-binding \
--role="roles/iam.workloadIdentityUser" \
--member="serviceAccount:YOUR-GOOGLE-CLOUD-PROJECT.svc.id.goog[YOUR-K8S-NAMESPACE/YOUR-KSA-NAME]" \
YOUR-GSA-NAME@YOUR-GOOGLE-CLOUD-PROJECT.iam.gserviceaccount.com
```

### Deploy Cloud SQL Proxy and Test Connectivity
There's a `deploy.yaml` file that sets up the Cloud SQL Proxy deployment and service. Note that it's configured to listen to PostgreSQL via the `-instances` flag and expose it on port 5432.

It should follow the following format:
```yaml
-instances=<PROJECT_NAME>:<REGION>:<DATABASE_INSTANCE>=tcp:0.0.0.0:5432
```

There's a `test-connectivity.yaml` file that will deploy a test pod to check the connectivity to your PostgreSQL instance via the Cloud SQL Proxy, **Make sure you adjust the file with your credentials.**

To test connectivity, you may use the following commands :
1. First, list the running pods in your cluster:
```
kubectl get pods -n cloud-sql-proxy-operator-system
```
2. Find the name of the pod you want to SSH into (in this case, the pod running the `sql-client-connectivity-test` container) and run the following command to SSH into it:
```
kubectl exec -it POD_NAME -n cloud-sql-proxy-operator-system -- /bin/bash
```
Replace POD_NAME with the actual pod name and `YOUR_NAMESPACE` with the namespace your pod is running in.
3. Now that you are inside the pod, run the psql command to connect to the PostgreSQL database:
```
psql -h $INSTANCE_HOST -p $DB_PORT -U $DB_USER -W -d $DB_NAME
```
When prompted for the password, enter the value you set for `POSTGRES_PASSWORD.`

After entering the password, you should be connected to the PostgreSQL database and see the psql prompt. You can now run SQL queries and commands against your PostgreSQL instance.
