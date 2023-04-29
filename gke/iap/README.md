# Enabling IAP for GKE

This tutorial will guide you on how to secure a Google Kubernetes Engine (GKE) instance with Identity-Aware Proxy (IAP).

## Overview

IAP is integrated through [Ingress](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress) for GKE. This integration enables you to control resource-level access for employees instead of using a VPN.

## Prerequisites

To enable IAP for GKE, you need the following:

1. A Google Cloud console project with billing enabled.
2. A group of one or more GKE instances, served by an HTTPS load balancer. The load balancer should be created automatically when you create an Ingress object in a GKE cluster. Learn about creating an [Ingress for HTTPS](https://cloud.google.com/kubernetes-engine/docs/tutorials/configuring-domain-name-static-ip#create_an_ingress_for_https).
   - NOTE: internal Ingress requires a [BeyondCorp Enterprise](https://cloud.google.com/beyondcorp-enterprise/docs) subscription.
3. A domain name registered to the address of your load balancer.
4. App code to verify that all requests have an identity. Learn about [getting the user's identity](https://cloud.google.com/iap/docs/authentication-howto#iap_make_request).

## Enabling IAP

### 1. Configuring the OAuth consent screen

If you haven't configured your project's OAuth consent screen, you need to do so. An email address and product name are required for the OAuth consent screen.

1. Go to the [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent).
2. Under **Support email**, select the email address you want to display as a public contact. The email address must belong to the currently logged in user account or to a Google Group for which the currently logged in user is a [manager or owner](https://support.google.com/a/answer/167094).
3. Enter the **Application name** you want to display.
4. Add any optional details you'd like.
5. Click **Save.**

### 2. Creating OAuth credentials

1. Go to the [Credentials page](https://console.cloud.google.com/apis/credentials).
2. In the **Create credentials** drop-down, select **OAuth client ID.**
3. Under **Application type**, select **Web application.**
4. Add a **Name** for your OAuth client ID.
5. Click **Create.**
6. Your OAuth client ID and client secret are generated and displayed on the **OAuth client** window.
7. In the **Oauth client created** dialog, copy the client ID to the clipboard.
8. Click **OK.**
9. Click the name of the client that you just created to reopen it for editing.
10. In the **Authorized redirect URIs** field, enter the following string:
```
https://iap.googleapis.com/v1/oauth/clientIds/<CLIENT_ID>:handleRedirect
```
where `CLIENT_ID` is the OAuth client ID you just copied to the clipboard.
### 3. Setting up IAP access

1. Go to the [Identity-Aware Proxy page](https://console.cloud.google.com/security/iap).
2. Select the project you want to secure with IAP.
3. Select the checkbox next to the resource you want to grant access to.
4. On the right side panel, click **Add principal.**
5. In the **Add principals** dialog that appears, enter the email addresses of groups or individuals who should have the **IAP-secured Web App User** role for the project. The following kinds of principals can have this role:
   - **Google Account**: user@gmail.com
   - **Google Group**: admins@googlegroups.com
   - **Service account**: server@example.gserviceaccount.com
   - **Google Workspace domain**: example.com
   
    Make sure to add a Google Account that you have access to.
6. Select **Cloud IAP** > **IAP-secured Web App User** from the Roles drop-down list.
7. Click **Save.**

### 4. Configuring BackendConfig

To configure BackendConfig for IAP, create a Kubernetes Secret and then add an `iap` block to the BackendConfig.

#### Creating a Kubernetes Secret
The BackendConfig uses a Kubernetes `Secret` to wrap the OAuth client you created earlier. Kubernetes Secrets are managed like other Kubernetes objects by using the `kubectl` command-line interface (CLI). To create a Secret, run the following command where **client_id_key** and **client_secret_key** are the keys from the JSON file you downloaded when you created OAuth credentials:
```yaml
kubectl create secret generic my-secret --from-literal=client_id=client_id_key \
    --from-literal=client_secret=client_secret_key
```

#### Adding an iap block to the BackendConfig
For GKE versions 1.16.8-gke.3 and higher, use the `cloud.google.com/v1` API version. If you are using an earlier GKE version, use `cloud.google.com/v1beta1`.
```yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: config-default
  namespace: my-namespace
spec:
  iap:
    enabled: true
    oauthclientCredentials:
      secretName: my-secret
```
You also need to associate Service ports with your BackendConfig to trigger turning on IAP. One way to make this association is to make all ports for the service default to your BackendConfig, which you can do by adding the following annotation to your Service resource:
```yaml
metadata:
  annotations:
    beta.cloud.google.com/backend-config: '{"default": "config-default"}'
```

### Turning IAP off
To turn IAP off, you must set `enabled` to `false` in the **BackendConfig**. If you delete the IAP block from BackendConfig, the settings will persist. For example, if IAP is enabled with `secretName: my_secret` and you delete the block, then IAP will still be turned on with the OAuth credentials stored in `my_secret.`
