# Step 4: Configure and Test with APIOps

This guide demonstrates how to use Deck for declarative API configuration management (APIOps) and verify that your Python plugin is working correctly.

## Prerequisites

- Completed [Step 3: Deploy Data Plane with Python Plugin](./03_deploy_data_plane.md)
- [Deck CLI installed](https://docs.konghq.com/deck/latest/installation/)
- Data plane running and connected to Konnect

## Why Use Deck Instead of Kubernetes CRDs?

When using Kong Gateway Operator with Konnect in hybrid mode:

### Single Source of Truth Principle

- **Control Plane (Konnect)** is the authoritative source for API configuration
- **Deck** manages configuration declaratively in Konnect
- **Kubernetes CRDs** (KongService, KongRoute, KongPlugin) are designed for Kong Ingress Controller (KIC), not the Gateway Operator + Konnect setup

### When to Use Each Approach

| Tool | Use Case |
|------|----------|
| **Deck** | Kong Gateway + Konnect (this project) |
| **Kubernetes CRDs** | Kong Ingress Controller (KIC) |
| **Admin API** | Manual configuration or automation scripts |

Using Deck provides:
- Version-controlled configuration
- GitOps workflows
- Configuration drift detection
- Multi-environment management

## Understanding the Helper Scripts

This project includes three helper scripts:

1. **`ping.sh`**: Health check for Kong Admin API
2. **`dump_config.sh`**: Export current configuration from Kong
3. **`sync_config.sh`**: Apply configuration to Kong using Deck

Let's explore each one.

## Step 4.1: Verify Kong Admin API Access

First, verify you can reach the Kong Admin API:

```bash
./ping.sh
```

### What This Does

The script:
1. Gets the Kong Admin API Service URL (via port-forward or direct service)
2. Sends a GET request to the `/` endpoint
3. Displays the response with Kong Gateway version information

Expected output:
```json
{
  "version": "3.13.0.0-enterprise-edition",
  "tagline": "Welcome to kong",
  ...
}
```

### Troubleshooting Ping Issues

If ping fails:

```bash
# Check if the data plane is running
kubectl -n kong get pods -l app=dataplane-with-plugin-dataplane

# Check the Admin API service
kubectl -n kong get svc

# Port-forward to Admin API manually
kubectl -n kong port-forward svc/dataplane-with-plugin-dataplane-admin 8444:8444
```

## Step 4.2: Review Current Configuration

Export the current Kong configuration:

```bash
./dump_config.sh
```

### What This Does

This script uses Deck to:
1. Connect to your Konnect control plane
2. Download the current configuration
3. Save it to a local file (usually `konnect-export.yaml`)

This helps you:
- Understand the current state
- Create backups before making changes
- Detect configuration drift

### Understanding the Configuration Format

The exported YAML file contains:
- **Services**: Upstream APIs that Kong proxies to
- **Routes**: Request paths and methods that map to services
- **Plugins**: Features applied to services, routes, or globally
- **Upstreams & Targets**: Load balancing configuration

## Step 4.3: Review the Example Configuration

Examine the included configuration file:

```bash
cat konnect-export.yaml
```

This file defines:
1. A service pointing to `httpbin.konghq.com` (a test API)
2. A route with path `/mock`
3. The `myplugin` Python plugin attached to the route

### Configuration Structure

```yaml
services:
  - name: mock-service
    url: http://httpbin.konghq.com
    routes:
      - name: mock-route
        paths:
          - /mock
        plugins:
          - name: myplugin
            config:
              message: "Hello from Python Plugin"
              header_name: "x-hello-from-python"
```

## Step 4.4: Apply Configuration with Deck

Sync the configuration to your Kong Gateway:

```bash
./sync_config.sh
```

### What This Does

The script:
1. Validates the configuration file
2. Compares it with the current state in Konnect
3. Applies necessary changes (creates, updates, or deletes resources)
4. Displays a summary of changes made

Expected output:
```
Summary:
  Created: 2
  Updated: 0
  Deleted: 0
```

### Deck Sync Options

The sync process is:
- **Idempotent**: Safe to run multiple times
- **Declarative**: Only the resources in the file exist after sync
- **Atomic**: Changes are applied as a transaction

## Step 4.5: Deploy Test Pod

Create an nginx pod inside the cluster to test the Kong proxy:

```bash
kubectl -n kong create deployment nginx --image=nginx
```

This pod will act as a client to send requests to Kong from within the cluster.

### Wait for Pod to be Ready

```bash
kubectl -n kong wait --for=condition=Ready pod -l app=nginx --timeout=60s
```

## Step 4.6: Get Kong Proxy Service IP

Retrieve the Kong proxy service cluster IP:

```bash
export KONG_PROXY_IP=$(kubectl -n kong get svc dataplane-with-plugin-dataplane-proxy -o jsonpath='{.spec.clusterIP}')
echo "Kong Proxy IP: $KONG_PROXY_IP"
```

Save this IP for the next step.

## Step 4.7: Test the Python Plugin

Send a test request through Kong to verify the Python plugin is working:

```bash
kubectl -n kong exec deployment/nginx -- \
  curl -v "http://$KONG_PROXY_IP/mock/anything" \
  --no-progress-meter --fail-with-body
```

### Alternative: Using Pod Name

If you prefer to specify the pod directly:

```bash
# Get the nginx pod name
NGINX_POD=$(kubectl -n kong get pod -l app=nginx -o jsonpath='{.items[0].metadata.name}')

# Execute curl
kubectl -n kong exec pod/$NGINX_POD -- \
  curl -v "http://$KONG_PROXY_IP/mock/anything"
```

## Step 4.8: Verify Plugin Response

Examine the response headers to confirm the Python plugin executed successfully.

### Expected Output

```
< HTTP/1.1 200 OK
< Content-Type: application/json
< x-hello-from-python: Python says Hello from Python Plugin to 10.109.85.121
< x-python-pid: 2728
< Via: 1.1 kong/3.13.0.0-enterprise-edition
```

### Key Headers to Look For

1. **`x-hello-from-python`**: Custom header added by your Python plugin
   - Contains the message from plugin configuration
   - Includes the host from the request

2. **`x-python-pid`**: Process ID of the Python plugin server
   - Confirms the plugin server is running
   - Useful for debugging and process tracking

3. **`Via`**: Shows the request went through Kong Gateway

### Full Response Example

```json
{
  "args": {},
  "data": "",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Connection": "keep-alive",
    "Host": "httpbin.konghq.com",
    "User-Agent": "curl/8.14.1",
    "X-Forwarded-Host": "10.109.85.121",
    "X-Forwarded-Path": "/mock/anything",
    "X-Kong-Request-Id": "e1a6ee290dbdfc5ffcee113ced85cb06"
  },
  "method": "GET",
  "url": "http://10.109.85.121/anything"
}
```

### Response Headers

```
HTTP/1.1 200 OK
Content-Type: application/json
x-hello-from-python: Python says Hello from Python Plugin to 10.109.85.121
x-python-pid: 2728
Server: gunicorn/19.9.0
X-Kong-Upstream-Latency: 1104
X-Kong-Proxy-Latency: 186
Via: 1.1 kong/3.13.0.0-enterprise-edition
```

If you see both custom headers (`x-hello-from-python` and `x-python-pid`), your Python plugin is working correctly!

## Step 4.9: Test from Outside the Cluster (Optional)

To access Kong from your local machine, use port-forwarding:

```bash
kubectl -n kong port-forward svc/dataplane-with-plugin-dataplane-proxy 8000:80
```

Then in another terminal:

```bash
curl -v http://localhost:8000/mock/anything
```

## Testing Different Plugin Configurations

### Update Plugin Configuration

Edit `konnect-export.yaml` and change the plugin config:

```yaml
plugins:
  - name: myplugin
    config:
      message: "Greetings from Python"  # Changed message
      header_name: "x-hello-from-python"
```

Apply the changes:

```bash
./sync_config.sh
```

Test again:

```bash
kubectl -n kong exec deployment/nginx -- \
  curl -s "http://$KONG_PROXY_IP/mock/anything" | jq -r '.headers'
```

The message in `x-hello-from-python` should now say "Greetings from Python".

## Troubleshooting

### Plugin Not Executing

If you don't see the custom headers:

1. **Check plugin configuration**:
   ```bash
   ./dump_config.sh
   cat konnect-export.yaml | grep -A 10 plugins
   ```

2. **Verify plugin is enabled**:
   ```bash
   kubectl -n kong exec deployment/dataplane-with-plugin-dataplane -- kong plugins list
   ```

3. **Check Kong logs**:
   ```bash
   kubectl -n kong logs -l app=dataplane-with-plugin-dataplane --tail=100
   ```

### Route Not Found (404)

If you get a 404 error:

1. **Verify the route exists**:
   ```bash
   ./dump_config.sh
   cat konnect-export.yaml | grep -A 5 routes
   ```

2. **Check the path**:
   - Routes are defined with specific paths (e.g., `/mock`)
   - Ensure your request matches: `http://KONG_IP/mock/anything`

3. **Verify in Konnect UI**:
   - Log into Konnect
   - Navigate to Gateway Manager → Your Control Plane
   - Check Services and Routes

### Deck Sync Fails

If `./sync_config.sh` fails:

1. **Check Deck authentication**:
   ```bash
   # Verify KONNECT_TOKEN is set
   echo $KONNECT_TOKEN
   ```

2. **Validate configuration**:
   ```bash
   deck file validate konnect-export.yaml
   ```

3. **Check for syntax errors** in the YAML file

### Connection Refused

If you can't connect to Kong:

1. **Verify data plane is running**:
   ```bash
   kubectl -n kong get pods -l app=dataplane-with-plugin-dataplane
   ```

2. **Check service endpoints**:
   ```bash
   kubectl -n kong get endpoints
   ```

3. **Verify the service cluster IP**:
   ```bash
   kubectl -n kong get svc
   ```

## Next Steps

Congratulations! You've successfully:
- Deployed Kong Gateway Operator with Konnect integration
- Built and deployed a custom Python plugin
- Configured Kong using declarative APIOps with Deck
- Verified the plugin is working correctly

### Extending This Example

From here, you can:

1. **Customize the plugin**: Modify `myplugin.py` to add your own logic
2. **Add more routes**: Extend `konnect-export.yaml` with additional services and routes
3. **Try other plugins**: Enable Kong's built-in plugins (rate-limiting, authentication, etc.)
4. **Deploy to production**: Use these patterns in a production Kubernetes cluster

### Recommended Reading

- [Kong Plugin Development Guide](https://docs.konghq.com/gateway/latest/plugin-development/)
- [Deck Best Practices](https://docs.konghq.com/deck/latest/guides/best-practices/)
- [Kong Gateway Operator Production Guide](https://docs.konghq.com/gateway-operator/latest/production/)
- [GitOps with Kong and Deck](https://docs.konghq.com/deck/latest/guides/ci-cd/)

## Cleanup

To remove all resources:

```bash
# Delete the test nginx pod
kubectl -n kong delete deployment nginx

# Delete the data plane
kubectl -n kong delete dataplane dataplane-with-plugin

# Delete the control plane
kubectl -n kong delete konnectgatewaycontrolplane gateway-control-plane

# Delete Konnect auth
kubectl -n kong delete konnectapiauthconfiguration konnect-api-auth

# Delete the Kong namespace
kubectl delete namespace kong

# Uninstall the operator
helm uninstall kong-operator -n kong-system

# Delete the operator namespace
kubectl delete namespace kong-system

# Stop Minikube
minikube stop
```

## Additional Resources

- [Deck CLI Reference](https://docs.konghq.com/deck/latest/reference/deck/)
- [Kong Configuration Reference](https://docs.konghq.com/gateway/latest/reference/configuration/)
- [Kong Admin API Documentation](https://docs.konghq.com/gateway/latest/admin-api/)
- [Python PDK API Reference](https://docs.konghq.com/gateway/latest/plugin-development/pdk/python/)

---

**Back to:** [← README](./README.md) | **Previous:** [← Step 3: Deploy Data Plane](./03_deploy_data_plane.md)