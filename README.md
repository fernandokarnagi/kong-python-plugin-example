# Kong Python Plugin Example

A complete, production-ready example of building and deploying custom Python plugins for Kong Gateway on Kubernetes using Kong Konnect and the Kong Gateway Operator.

## Overview

This repository demonstrates how to:
- Create a custom Python plugin for Kong Gateway
- Build a custom Kong Gateway Docker image with Python plugin support
- Deploy Kong Gateway on Kubernetes using the Kong Gateway Operator
- Integrate with Kong Konnect for centralized control plane management
- Configure and test Python plugins in a hybrid deployment mode
- Manage API configurations using declarative APIOps with Deck

## What This Plugin Does

The example `myplugin` is a simple Python plugin that:
- Intercepts HTTP requests in the access phase
- Adds custom headers to the response:
  - `x-hello-from-python`: A customizable greeting message with the host
  - `x-python-pid`: The process ID of the Python plugin server
- Demonstrates the Kong PDK (Plugin Development Kit) for Python
- Shows how to define configuration schema with validation

## Architecture

This project uses a **hybrid deployment architecture**:
- **Control Plane**: Managed by Kong Konnect (cloud-based)
- **Data Plane**: Deployed on Kubernetes using the Kong Gateway Operator
- **Configuration Management**: Declarative APIOps using Deck CLI

```
┌─────────────────────────┐
│   Kong Konnect          │
│   (Control Plane)       │
└───────────┬─────────────┘
            │
            │ Configuration
            │ Synchronization
            │
┌───────────▼─────────────┐
│   Kubernetes Cluster    │
│                         │
│  ┌──────────────────┐   │
│  │  Data Plane      │   │
│  │  (Kong Gateway)  │   │
│  │                  │   │
│  │  + Python Plugin │   │
│  └──────────────────┘   │
└─────────────────────────┘
```

## Prerequisites

Before getting started, ensure you have:

### Required Tools
- **Kubernetes Cluster**: Minikube, Kind, or any Kubernetes cluster (v1.25+)
- **kubectl**: Kubernetes CLI configured with cluster access
- **Helm**: Package manager for Kubernetes (v3+)
- **Docker**: For building custom Kong images
- **deck**: Kong's declarative configuration tool ([installation guide](https://docs.konghq.com/deck/latest/installation/))

### Kong Konnect Account
- A Kong Konnect account ([sign up here](https://konghq.com/products/kong-konnect))
- A Personal Access Token (PAT) or System Account Token

### Knowledge Prerequisites
- Basic understanding of Kubernetes concepts (Pods, Deployments, Services)
- Familiarity with Kong Gateway concepts (Routes, Services, Plugins)
- Basic Python programming knowledge

## Quick Start

Follow these guides in order:

### 1. [Install Kong Gateway Operator](./01_k8s_operator.md)
Set up Minikube and install the Kong Gateway Operator with Konnect integration enabled.

### 2. [Create Control Plane in Konnect](./02_create_control_plane.md)
Configure authentication and create a control plane in Kong Konnect using Kubernetes CRDs.

### 3. [Deploy Data Plane with Python Plugin](./03_deploy_data_plane.md)
Build the custom Kong image with Python plugin support and deploy the data plane to Kubernetes.

### 4. [Configure and Test with APIOps](./04_api_ops.md)
Use Deck to configure Kong Gateway declaratively and verify the Python plugin is working.

## Project Structure

```
.
├── README.md                      # This file
├── 01_k8s_operator.md            # Step 1: Kong Operator installation
├── 02_create_control_plane.md    # Step 2: Konnect control plane setup
├── 03_deploy_data_plane.md       # Step 3: Data plane deployment
├── 04_api_ops.md                 # Step 4: APIOps configuration
│
├── myplugin.py                   # Python plugin implementation
├── kong-pluginserver.py          # Plugin server entry point
├── Dockerfile                    # Custom Kong Gateway image
├── requirements.txt              # Python dependencies
│
├── konnect-export.yaml           # Sample Deck configuration
├── dump_config.sh                # Export configuration from Kong
├── sync_config.sh                # Sync configuration to Kong
└── ping.sh                       # Health check script
```

## Key Files Explained

### Python Plugin Files

- **`myplugin.py`**: The main plugin implementation
  - Defines the plugin schema (configuration options)
  - Implements the `access` phase handler
  - Sets custom response headers

- **`kong-pluginserver.py`**: Plugin server bootstrap
  - Entry point for the Kong plugin server
  - Configures the Python path for Kong PDK

- **`requirements.txt`**: Python dependencies
  - Currently includes `kong-pdk` (Kong Plugin Development Kit)

### Docker Configuration

- **`Dockerfile`**: Custom Kong Gateway image
  - Based on official `kong/kong-gateway:latest`
  - Installs Python 3 and pip
  - Installs kong-pdk and plugin files
  - Configures proper permissions

### Deck Configuration

- **`konnect-export.yaml`**: Example Kong configuration
  - Defines services, routes, and plugin configurations
  - Used for declarative APIOps workflow

### Helper Scripts

- **`ping.sh`**: Ping the Kong Admin API
- **`dump_config.sh`**: Export current configuration from Kong
- **`sync_config.sh`**: Apply configuration to Kong using Deck

## How Python Plugins Work in Kong

Kong Gateway supports external plugin servers through a plugin server protocol. For Python plugins:

1. **Plugin Server**: Kong communicates with a Python plugin server process via Unix socket
2. **Kong PDK**: The Python plugin uses the Kong PDK to interact with Kong's core
3. **Schema Registration**: Even for Python plugins, a Lua schema is needed for validation
4. **Process Lifecycle**: The plugin server runs as a separate process alongside Kong

### Environment Variables Configuration

The following environment variables enable Python plugin support:

```yaml
KONG_PLUGINSERVER_NAMES: "myplugin"
KONG_PLUGINSERVER_MYPLUGIN_SOCKET: "/usr/local/kong/python_pluginserver.sock"
KONG_PLUGINSERVER_MYPLUGIN_START_CMD: "/opt/kong-python-plugins/kong-pluginserver.py --plugins-directory /opt/kong-python-plugins/plugins"
KONG_PLUGINSERVER_MYPLUGIN_QUERY_CMD: "/opt/kong-python-plugins/kong-pluginserver.py --plugins-directory /opt/kong-python-plugins/plugins --dump-all-plugins"
KONG_PLUGINS: "bundled,myplugin"
```

## Customizing the Plugin

To create your own Python plugin:

1. **Modify `myplugin.py`**:
   - Update the `Schema` to define your configuration options
   - Implement plugin phases: `access`, `header_filter`, `body_filter`, etc.
   - Use the Kong PDK to interact with requests and responses

2. **Update the Dockerfile**:
   - Change the plugin file name if needed
   - Add any additional Python dependencies to `requirements.txt`

3. **Rebuild and redeploy**:
   ```bash
   docker build -t your-plugin-name:version .
   minikube image load your-plugin-name:version
   kubectl apply -f your-dataplane-config.yaml
   ```

## APIOps Workflow

This project follows a declarative APIOps approach:

1. **Single Source of Truth**: Configuration is stored in `konnect-export.yaml`
2. **Version Control**: Track all changes in Git
3. **Automated Sync**: Use Deck to apply configurations
4. **Validation**: Deck validates configurations before applying

Why not use Kubernetes CRDs (KongPlugin, KongService, etc.)?
- CRDs are recommended for Kong Ingress Controller (KIC)
- For Kong Gateway Operator with Konnect, the control plane in Konnect is the source of truth
- Deck provides a unified workflow across different deployment models

## Testing the Plugin

After deployment, verify the plugin is working:

```bash
# Deploy a test pod
kubectl -n kong create deployment nginx --image=nginx

# Get the Kong proxy service cluster IP
kubectl -n kong get svc

# Test the plugin (replace CLUSTER_IP with your Kong proxy service IP)
kubectl -n kong exec deployment/nginx -- curl -v "http://CLUSTER_IP/mock/anything"
```

Look for the custom headers in the response:
```
x-hello-from-python: Python says Hello from Python Plugin to CLUSTER_IP
x-python-pid: 2728
```

## Troubleshooting

### Plugin Not Loading

Check the Kong Gateway logs:
```bash
kubectl -n kong logs deployment/dataplane-with-plugin-dataplane -c proxy
```

Look for plugin server startup messages and any Python errors.

### Configuration Not Syncing

Verify the Konnect connection:
```bash
kubectl get -n kong konnectgatewaycontrolplane gateway-control-plane -o yaml
```

Check the `status.conditions` for any errors.

### Python Dependencies Issues

If you add new Python dependencies:
1. Add them to `requirements.txt`
2. Rebuild the Docker image
3. Load it into Minikube: `minikube image load your-image:tag`
4. Restart the data plane deployment

## Additional Resources

- [Kong Plugin Development Guide](https://docs.konghq.com/gateway/latest/plugin-development/)
- [Kong Python PDK Documentation](https://docs.konghq.com/gateway/latest/plugin-development/pdk/python/)
- [Kong Gateway Operator Documentation](https://docs.konghq.com/gateway-operator/latest/)
- [Kong Konnect Documentation](https://docs.konghq.com/konnect/)
- [Deck Documentation](https://docs.konghq.com/deck/latest/)

## Contributing

Contributions are welcome! Feel free to:
- Report issues
- Submit pull requests
- Improve documentation
- Share your own plugin examples

## License

This project is provided as-is for educational and example purposes.

## Support

For questions or issues:
- Kong Community Forum: https://discuss.konghq.com/
- Kong GitHub Issues: https://github.com/Kong/kong/issues
- Kong Documentation: https://docs.konghq.com/

---

Built with ❤️ for the Kong community
