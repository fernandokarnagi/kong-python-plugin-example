# Step 3: Deploy Data Plane with Python Plugin

This guide walks through building a custom Kong Gateway Docker image with Python plugin support and deploying it as a data plane in your Kubernetes cluster.

## Prerequisites

- Completed [Step 2: Create Control Plane in Kong Konnect](./02_create_control_plane.md)
- Docker installed and running
- Minikube running
- Basic understanding of Docker and Kong Gateway

## Overview

In this step, you'll:
1. Configure the Konnect extension for data plane connectivity
2. Build a custom Kong Gateway Docker image with Python support
3. Load the image into Minikube
4. Deploy the data plane with Python plugin configuration
5. Verify the deployment

## Understanding Python Plugins in Kong

Kong Gateway's core is written in Lua, so even Python plugins require some Lua integration:

### Why a Lua Schema is Required

Python plugins still need a Lua schema file because:
1. **Validation**: Kong's Admin API uses Lua to validate plugin configurations
2. **Registration**: The plugin must be registered in Kong's core (Lua-based)
3. **Control Plane**: The control plane needs schema information for configuration management

### How Python Plugins Work

```
┌─────────────────┐
│  Kong Gateway   │
│   (Lua Core)    │
└────────┬────────┘
         │
         │ Plugin Server Protocol
         │ (Unix Socket)
         │
┌────────▼─────────────┐
│  Python Plugin Server │
│  (kong-pluginserver) │
│                      │
│  - myplugin.py       │
│  - Other plugins...  │
└──────────────────────┘
```

Kong communicates with the Python plugin server via a Unix socket using a plugin server protocol.

## Step 3.1: Set Environment Variable (If Not Set)

If you closed your terminal since Step 2, re-export your Konnect token:

```bash
export KONNECT_TOKEN=kpat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Step 3.2: Create Konnect Extension

Create a `KonnectExtension` resource to configure the data plane connection to your control plane:

```bash
kubectl apply -f - <<EOF
kind: KonnectExtension
apiVersion: konnect.konghq.com/v1alpha2
metadata:
  name: konnect-config
  namespace: kong
spec:
  clientAuth:
    certificateSecret:
      provisioning: Automatic
  konnect:
    controlPlane:
      ref:
        type: konnectNamespacedRef
        konnectNamespacedRef:
          name: gateway-control-plane
EOF
```

### What This Does

- `clientAuth.certificateSecret.provisioning: Automatic`: Automatically generates and manages TLS certificates for secure communication between data plane and control plane
- `controlPlane.ref`: References the control plane created in Step 2
- The operator will handle certificate generation and rotation

## Step 3.3: Build Custom Kong Gateway Image

Build the Docker image with Python plugin support:

```bash
docker build -t konggtwpythonplugin:0.0.1 -f Dockerfile .
```

### What the Dockerfile Does

The Dockerfile (see project root):
1. Starts from the official Kong Gateway image
2. Installs Python 3 and pip
3. Installs the `kong-pdk` Python package
4. Copies your plugin files to `/opt/kong-python-plugins/`
5. Sets proper permissions
6. Configures the entry point

### Key Components Installed

- **Python 3**: Runtime for Python plugins
- **kong-pdk**: Kong Plugin Development Kit for Python
- **myplugin.py**: Your custom plugin implementation
- **kong-pluginserver.py**: Plugin server bootstrap script

## Step 3.4: Load Image into Minikube

Since we're using Minikube, load the image into Minikube's internal registry:

```bash
minikube image load konggtwpythonplugin:0.0.1
```

This avoids the need to push to a remote registry or configure image pull secrets.

### Verify Image is Loaded

```bash
minikube image ls | grep konggtwpythonplugin
```

You should see `konggtwpythonplugin:0.0.1` in the output.

## Step 3.5: Deploy Data Plane

Deploy the Kong Gateway data plane with Python plugin configuration:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway-operator.konghq.com/v1beta1
kind: DataPlane
metadata:
  name: dataplane-with-plugin
  namespace: kong
spec:
  extensions:
  - kind: KonnectExtension
    name: konnect-config
    group: konnect.konghq.com
  deployment:
    replicas: 1
    podTemplateSpec:
      spec:
        containers:
        - name: proxy
          image: konggtwpythonplugin:0.0.1
          env:
          - name: KONG_PLUGINSERVER_NAMES
            value: "myplugin"
          - name: KONG_PLUGINSERVER_MYPLUGIN_SOCKET
            value: "/usr/local/kong/python_pluginserver.sock"
          - name: KONG_PLUGINSERVER_MYPLUGIN_START_CMD
            value: "/opt/kong-python-plugins/kong-pluginserver.py --plugins-directory /opt/kong-python-plugins/plugins"
          - name: KONG_PLUGINSERVER_MYPLUGIN_QUERY_CMD
            value: "/opt/kong-python-plugins/kong-pluginserver.py --plugins-directory /opt/kong-python-plugins/plugins --dump-all-plugins"
          - name: KONG_PLUGINS
            value: "bundled,myplugin"
          - name: KONG_LOG_LEVEL
            value: "debug"
          - name: KONG_PROXY_ACCESS_LOG
            value: "/dev/stdout"
          - name: KONG_ADMIN_ACCESS_LOG
            value: "/dev/stdout"
          - name: KONG_PROXY_ERROR_LOG
            value: "/dev/stderr"
          - name: KONG_ADMIN_ERROR_LOG
            value: "/dev/stderr"
EOF
```

### Environment Variables Explained

#### Plugin Server Configuration

- **`KONG_PLUGINSERVER_NAMES`**: Name of the plugin server (must match plugin name)
- **`KONG_PLUGINSERVER_MYPLUGIN_SOCKET`**: Unix socket path for communication
- **`KONG_PLUGINSERVER_MYPLUGIN_START_CMD`**: Command to start the plugin server
- **`KONG_PLUGINSERVER_MYPLUGIN_QUERY_CMD`**: Command to query available plugins

#### Kong Configuration

- **`KONG_PLUGINS`**: List of enabled plugins (`bundled` = all built-in plugins, `myplugin` = your custom plugin)
- **`KONG_LOG_LEVEL`**: Set to `debug` for detailed logging (use `info` in production)

#### Logging Configuration

- **`KONG_PROXY_ACCESS_LOG`**: Proxy access logs to stdout
- **`KONG_ADMIN_ACCESS_LOG`**: Admin API access logs to stdout
- **`KONG_PROXY_ERROR_LOG`**: Proxy error logs to stderr
- **`KONG_ADMIN_ERROR_LOG`**: Admin API error logs to stderr

These settings make logs available via `kubectl logs`.

## Step 3.6: Verify Deployment

### Wait for Data Plane to be Ready

```bash
kubectl -n kong wait --for=condition=Ready --timeout=300s pod -l app=dataplane-with-plugin-dataplane
```

### Check Pod Status

```bash
kubectl -n kong get pods -l app=dataplane-with-plugin-dataplane
```

Expected output:
```
NAME                                           READY   STATUS    RESTARTS   AGE
dataplane-with-plugin-dataplane-xxxxx-xxxxx    1/1     Running   0          2m
```

### View Data Plane Resources

```bash
kubectl -n kong get dataplane
```

### Check Data Plane Logs

View the logs to verify the Python plugin server started correctly:

```bash
kubectl -n kong logs -l app=dataplane-with-plugin-dataplane --tail=50
```

Look for messages indicating:
- Kong Gateway started successfully
- Python plugin server started
- Plugin "myplugin" registered
- Connection to control plane established

Example log snippets:
```
[pluginserver] starting pluginserver at: /usr/local/kong/python_pluginserver.sock
[pluginserver] plugin server started
Kong Gateway starting...
```

### Verify in Konnect UI

1. Log into [Kong Konnect](https://cloud.konghq.com/)
2. Navigate to **Gateway Manager** → Your control plane
3. Click on **Data Planes**
4. You should see your data plane connected with status "Connected"

## Step 3.7: Verify Python Plugin is Loaded

Check if Kong recognizes the Python plugin:

```bash
kubectl -n kong exec -it deployment/dataplane-with-plugin-dataplane -- kong plugins list
```

You should see `myplugin` in the list of available plugins.

## Troubleshooting

### Pod Not Starting

Check pod events:
```bash
kubectl -n kong describe pod -l app=dataplane-with-plugin-dataplane
```

Common issues:
- Image pull errors: Verify the image is loaded in Minikube
- Resource limits: Ensure sufficient cluster resources
- Configuration errors: Check environment variables

### Plugin Server Not Starting

View detailed logs:
```bash
kubectl -n kong logs -l app=dataplane-with-plugin-dataplane --tail=100
```

Look for:
- Python errors or import failures
- Socket permission issues
- Plugin file not found errors

### Data Plane Not Connecting to Control Plane

Check the Konnect extension status:
```bash
kubectl -n kong get konnectextension konnect-config -o yaml
```

Verify:
- Certificate was provisioned automatically
- Control plane reference is correct
- No authentication errors in logs

### Python Dependencies Issues

If you added custom dependencies to `requirements.txt`:
1. Rebuild the Docker image
2. Reload it into Minikube:
   ```bash
   docker build -t konggtwpythonplugin:0.0.1 -f Dockerfile .
   minikube image load konggtwpythonplugin:0.0.1
   ```
3. Restart the data plane:
   ```bash
   kubectl -n kong rollout restart deployment dataplane-with-plugin-dataplane
   ```

## What's Next?

Now that your data plane is running with the Python plugin, proceed to:

**[Step 4: Configure and Test with APIOps →](./04_api_ops.md)**

This will show you how to configure Kong Gateway using Deck and verify that your Python plugin is working correctly.

## Additional Resources

- [Kong Gateway Data Planes Documentation](https://docs.konghq.com/gateway-operator/latest/production/data-plane/)
- [Kong Python PDK Documentation](https://docs.konghq.com/gateway/latest/plugin-development/pdk/python/)
- [Kong Plugin Server Documentation](https://docs.konghq.com/gateway/latest/reference/external-plugins/)
- [Kong Gateway Configuration Reference](https://docs.konghq.com/gateway/latest/reference/configuration/)
