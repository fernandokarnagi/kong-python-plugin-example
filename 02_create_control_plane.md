# Step 2: Create Control Plane in Kong Konnect

This guide shows how to create a Kong Gateway control plane in Kong Konnect using Kubernetes Custom Resource Definitions (CRDs). The control plane will manage configuration for your data plane gateways.

## Prerequisites

- Completed [Step 1: Install Kong Gateway Operator](./01_k8s_operator.md)
- A Kong Konnect account ([sign up here](https://konghq.com/products/kong-konnect))
- A Konnect Personal Access Token (PAT) or System Account Token

## About Hybrid Deployment

Kong Gateway can run in **hybrid mode**, where:
- **Control Plane (CP)**: Manages configuration, hosted in Kong Konnect cloud
- **Data Plane (DP)**: Handles traffic, deployed in your Kubernetes cluster

This architecture provides:
- Centralized configuration management
- Simplified upgrades and scaling
- Better security (data plane has no database)
- Multi-region deployments with one control plane

## Step 2.1: Get Your Konnect Token

1. Log into [Kong Konnect](https://cloud.konghq.com/)
2. Navigate to **Personal Access Tokens** or **System Accounts**
3. Create a new token with appropriate permissions:
   - `Control Planes Admin` (or `Control Planes Write`)
   - `Services Admin`
   - `Routes Admin`
4. Copy the token value

## Step 2.2: Set Environment Variable

Export your Konnect token as an environment variable:

```bash
export KONNECT_TOKEN=kpat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Security Note:** Never commit tokens to version control. In production, use Kubernetes secrets or a secrets management solution.

## Step 2.3: Create Kong Namespace

Create the `kong` namespace where the data plane will run:

```bash
kubectl create namespace kong --dry-run=client -o yaml | kubectl apply -f -
```

The `--dry-run=client` flag with `kubectl apply` makes this command idempotent (safe to run multiple times).

## Step 2.4: Configure Konnect Authentication

Create a `KonnectAPIAuthConfiguration` resource to store the authentication credentials:

```bash
kubectl apply -f - <<EOF
kind: KonnectAPIAuthConfiguration
apiVersion: konnect.konghq.com/v1alpha1
metadata:
  name: konnect-api-auth
  namespace: kong
spec:
  type: token
  token: "${KONNECT_TOKEN}"
  serverURL: sg.api.konghq.com
EOF
```

### Configuration Details

- `type: token`: Uses token-based authentication
- `token`: Your Konnect API token (injected from environment variable)
- `serverURL`: The Konnect API endpoint
  - `us.api.konghq.com` - US region
  - `eu.api.konghq.com` - EU region
  - `sg.api.konghq.com` - Singapore region
  - `au.api.konghq.com` - Australia region

**Important:** Choose the serverURL that matches your Konnect account's region.

## Step 2.5: Create Control Plane

Create a `KonnectGatewayControlPlane` resource to provision a control plane in Konnect:

```bash
kubectl apply -f - <<EOF
kind: KonnectGatewayControlPlane
apiVersion: konnect.konghq.com/v1alpha2
metadata:
  name: gateway-control-plane
  namespace: kong
spec:
  createControlPlaneRequest:
    name: gateway-control-plane
  konnect:
    authRef:
      name: konnect-api-auth
EOF
```

This Custom Resource Definition (CRD) will:
1. Authenticate to Kong Konnect using the credentials from Step 2.4
2. Create a new control plane named "gateway-control-plane"
3. Configure the connection parameters for data planes

## Step 2.6: Verify Control Plane Creation

Check the status of the control plane:

```bash
kubectl get -n kong konnectgatewaycontrolplane gateway-control-plane \
  -o jsonpath='{.status.conditions[?(@.type=="Programmed")]}' | jq
```

Expected output when successful:

```json
{
  "lastTransitionTime": "2026-01-08T11:29:33Z",
  "message": "",
  "observedGeneration": 1,
  "reason": "Programmed",
  "status": "True",
  "type": "Programmed"
}
```

If the status is `"True"`, your control plane is ready.

### Check All Conditions

To see all status conditions:

```bash
kubectl get -n kong konnectgatewaycontrolplane gateway-control-plane -o yaml
```

Look for the `status` section at the bottom of the output.

## Step 2.7: Verify in Konnect UI

1. Log into [Kong Konnect](https://cloud.konghq.com/)
2. Navigate to **Gateway Manager**
3. You should see a control plane named "gateway-control-plane"
4. Note the Control Plane ID - you'll use this for configuration

## Troubleshooting

### Control Plane Not Programmed

If the status shows `"status": "False"`:

```bash
# Check the full status
kubectl describe -n kong konnectgatewaycontrolplane gateway-control-plane

# Check operator logs
kubectl -n kong-system logs deployment/kong-operator-kong-operator-controller-manager -c manager --tail=50
```

Common issues:
- Invalid Konnect token
- Wrong serverURL for your region
- Network connectivity issues

### Authentication Failed

If you see authentication errors:

```bash
# Verify the token is set correctly
kubectl get -n kong konnectapiauthconfiguration konnect-api-auth -o yaml
```

Re-create the auth configuration with the correct token:

```bash
kubectl delete -n kong konnectapiauthconfiguration konnect-api-auth
# Then run Step 2.4 again
```

### Region Mismatch

If you get 404 errors, verify your Konnect account region:
1. Check the URL when logged into Konnect
2. Update `serverURL` in the auth configuration accordingly

## What's Next?

Now that your control plane is configured, proceed to:

**[Step 3: Deploy Data Plane with Python Plugin →](./03_deploy_data_plane.md)**

This will build a custom Kong Gateway image with Python plugin support and deploy it to your Kubernetes cluster.

## Additional Resources

- [Kong Hybrid Mode Documentation](https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/)
- [Kong Gateway Operator Konnect CRD Reference](https://docs.konghq.com/gateway-operator/latest/customization/konnect/)
- [Konnect API Authentication](https://docs.konghq.com/konnect/api/)
- [Managing Control Planes in Konnect](https://docs.konghq.com/konnect/gateway-manager/)
