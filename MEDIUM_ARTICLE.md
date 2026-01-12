# Building Custom Kong Gateway Plugins with Python: A Complete Guide

## How to extend Kong Gateway with Python plugins in Kubernetes using the Gateway Operator and Kong Konnect

![Kong Gateway + Python](https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=1200)
*Photo by Markus Spiske on Unsplash*

---

When I first started working with Kong Gateway, I was amazed by its plugin ecosystem. Rate limiting, authentication, caching — everything you need is right there. But what happens when you need custom logic that's unique to your business? What if you want to leverage Python's rich ecosystem of libraries for machine learning, data processing, or complex business rules?

That's where custom Python plugins come in. And today, I'm going to show you exactly how to build, deploy, and test them in a production-like environment using Kubernetes.

## Why Python Plugins Matter

Kong Gateway's core is written in Lua, which is incredibly fast. But let's be honest — Python's ecosystem is unmatched. Need to:

- Call a machine learning model for intelligent routing?
- Process complex data transformations with pandas?
- Integrate with Python-first APIs and services?
- Leverage existing Python codebases in your organization?

Python plugins give you that flexibility without sacrificing Kong's performance.

## What We're Building

In this tutorial, we'll build a complete Kong Gateway setup with a custom Python plugin that:

✅ Runs on Kubernetes (using Minikube locally)
✅ Integrates with Kong Konnect for centralized control
✅ Uses the Kong Gateway Operator for declarative infrastructure
✅ Follows APIOps best practices with Deck
✅ Can be customized for your own use cases

By the end, you'll have a working example you can extend for production use.

## The Architecture

Before diving into code, let's understand the architecture:

```
┌─────────────────────────┐
│   Kong Konnect          │
│   (Control Plane)       │ ← Configuration Management
└───────────┬─────────────┘
            │
            │ Secure Connection
            │
┌───────────▼─────────────┐
│   Kubernetes Cluster    │
│                         │
│  ┌──────────────────┐   │
│  │  Kong Gateway    │   │
│  │  (Data Plane)    │   │
│  │                  │   │
│  │  ┌────────────┐  │   │
│  │  │  Python    │  │   │ ← Your Custom Logic
│  │  │  Plugin    │  │   │
│  │  │  Server    │  │   │
│  │  └────────────┘  │   │
│  └──────────────────┘   │
└─────────────────────────┘
```

This is a **hybrid deployment**: the control plane (configuration) lives in Kong Konnect's cloud, while the data plane (traffic handling) runs in your Kubernetes cluster.

**Why this architecture?**

- **Separation of concerns**: Configuration management is centralized
- **Scalability**: Deploy data planes in multiple regions
- **Security**: Data plane has no database, reducing attack surface
- **GitOps-friendly**: Manage configuration as code with Deck

## Prerequisites

To follow along, you'll need:

- **Kubernetes**: Minikube, Kind, or any cluster
- **Docker**: For building custom images
- **Helm**: To install the Kong Gateway Operator
- **Kong Konnect account**: Free tier works fine ([sign up here](https://konghq.com/products/kong-konnect))
- **Deck CLI**: For configuration management ([install guide](https://docs.konghq.com/deck/latest/installation/))

Don't worry if you're new to some of these tools — I'll explain each step.

---

# Part 1: The Foundation

## Setting Up the Kong Gateway Operator

First, let's get our Kubernetes cluster ready. I'm using Minikube for local development:

```bash
# Start Minikube
minikube start

# Set kubectl context
kubectl config set-context --current --namespace=kong

# Add Kong Helm repo
helm repo add kong https://charts.konghq.com
helm repo update
```

Now install the Kong Gateway Operator with Konnect support:

```bash
helm upgrade --install kong-operator kong/kong-operator \
  -n kong-system --create-namespace \
  --set image.tag=2.0.5 \
  --set env.ENABLE_CONTROLLER_KONNECT=true \
  --set env.VALIDATE_IMAGES=false \
  --set env.GATEWAY_OPERATOR_VALIDATE_IMAGES=false
```

**Key point**: We're disabling image validation because we'll build a custom Kong image with Python support. In production, implement proper image scanning in your CI/CD pipeline.

Verify the installation:

```bash
kubectl -n kong-system wait --for=condition=Available=true \
  --timeout=120s \
  deployment/kong-operator-kong-operator-controller-manager
```

✅ **Checkpoint**: You should see the operator pod running.

---

## Connecting to Kong Konnect

Now let's connect to Kong Konnect. First, get your API token:

1. Log into [Kong Konnect](https://cloud.konghq.com/)
2. Go to **Personal Access Tokens**
3. Create a token with `Control Planes Admin` permissions
4. Save the token securely

Set it as an environment variable:

```bash
export KONNECT_TOKEN=kpat_your_token_here
```

Create the authentication configuration:

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
  serverURL: us.api.konghq.com  # Change based on your region
EOF
```

**Pro tip**: For production, store tokens in Kubernetes secrets or a secrets manager like Vault.

Now create the control plane:

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

Verify it's programmed:

```bash
kubectl get -n kong konnectgatewaycontrolplane gateway-control-plane \
  -o jsonpath='{.status.conditions[?(@.type=="Programmed")]}'
```

You should see `"status": "True"`. 🎉

---

# Part 2: Building the Python Plugin

## Understanding How Python Plugins Work

Here's the magic: Kong's core is Lua, but it can communicate with external plugin servers over a Unix socket. Your Python code runs in a separate process, and Kong calls it when needed.

```
Request → Kong (Lua) → Unix Socket → Python Plugin Server → Your Code
```

This design is brilliant because:
- Plugins can be written in any language
- Plugin crashes don't take down Kong
- You can use language-specific libraries

## The Plugin Code

Let's create a simple plugin that adds custom headers. Here's `myplugin.py`:

```python
#!/usr/bin/env python3
import os
import kong_pdk.pdk.kong as kong
from kong_pdk.cli import start_dedicated_server

# Configuration schema
Schema = (
    {"message": {
        "type": "string",
        "required": True,
        "default": "Hello from Python Plugin"
    }},
    {"header_name": {
        "type": "string",
        "required": True,
        "default": "X-Custom-Header"
    }},
)

version = '0.1.0'
priority = 0

class Plugin(object):
    def __init__(self, config):
        self.config = config

    def access(self, kong: kong.kong):
        # Get the host header from the request
        host, err = kong.request.get_header("host")
        if err:
            pass  # Handle error

        # Get configured message
        message = self.config.get('message', 'hello')

        # Set custom response headers
        kong.response.set_header(
            "x-hello-from-python",
            f"Python says {message} to {host}"
        )
        kong.response.set_header(
            "x-python-pid",
            str(os.getpid())
        )

if __name__ == "__main__":
    start_dedicated_server("myplugin", Plugin, version, priority, Schema)
```

**What's happening here?**

1. **Schema**: Defines configuration options that users can set
2. **Plugin class**: Contains the plugin logic
3. **access phase**: Runs during the access phase of the request lifecycle
4. **Kong PDK**: The `kong` object gives you access to request/response data

## Building the Docker Image

Now we need to package this into a Kong Gateway image. Here's the `Dockerfile`:

```dockerfile
FROM kong/kong-gateway:latest

USER root

# Install Python and pip
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv

# Install Kong PDK
RUN pip3 install --break-system-packages kong-pdk && \
    python3 -c "import kong_pdk; print('kong-pdk installed successfully')"

# Copy plugin files
COPY ./kong-pluginserver.py /opt/kong-python-plugins/kong-pluginserver.py
COPY ./myplugin.py /opt/kong-python-plugins/plugins/myplugin.py
COPY ./requirements.txt /opt/kong-python-plugins/plugins/requirements.txt

# Set permissions
RUN chown -R kong:kong /opt/kong-python-plugins && \
    chmod -R 755 /opt/kong-python-plugins && \
    chmod +x /opt/kong-python-plugins/kong-pluginserver.py

# Install requirements
RUN pip3 install --break-system-packages \
    -r /opt/kong-python-plugins/plugins/requirements.txt

USER kong

ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 8000 8443 8001 8444
CMD ["kong", "docker-start"]
```

Build and load into Minikube:

```bash
# Build the image
docker build -t konggtwpythonplugin:0.0.1 -f Dockerfile .

# Load into Minikube (so we don't need a registry)
minikube image load konggtwpythonplugin:0.0.1
```

---

# Part 3: Deploying the Data Plane

## Configuring the Konnect Extension

First, configure how the data plane connects to the control plane:

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
      provisioning: Automatic  # Auto-generates TLS certs
  konnect:
    controlPlane:
      ref:
        type: konnectNamespacedRef
        konnectNamespacedRef:
          name: gateway-control-plane
EOF
```

## Deploying Kong with Python Plugin

Now for the main event — deploying Kong with our Python plugin:

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
          # Plugin server configuration
          - name: KONG_PLUGINSERVER_NAMES
            value: "myplugin"
          - name: KONG_PLUGINSERVER_MYPLUGIN_SOCKET
            value: "/usr/local/kong/python_pluginserver.sock"
          - name: KONG_PLUGINSERVER_MYPLUGIN_START_CMD
            value: "/opt/kong-python-plugins/kong-pluginserver.py --plugins-directory /opt/kong-python-plugins/plugins"
          - name: KONG_PLUGINSERVER_MYPLUGIN_QUERY_CMD
            value: "/opt/kong-python-plugins/kong-pluginserver.py --plugins-directory /opt/kong-python-plugins/plugins --dump-all-plugins"
          # Enable the plugin
          - name: KONG_PLUGINS
            value: "bundled,myplugin"
          # Logging
          - name: KONG_LOG_LEVEL
            value: "debug"
          - name: KONG_PROXY_ACCESS_LOG
            value: "/dev/stdout"
EOF
```

**Breaking down the environment variables:**

- `KONG_PLUGINSERVER_NAMES`: Register your plugin server
- `KONG_PLUGINSERVER_MYPLUGIN_SOCKET`: Unix socket location
- `KONG_PLUGINSERVER_MYPLUGIN_START_CMD`: How to start your plugin
- `KONG_PLUGINS`: Enable bundled plugins + your custom plugin
- Logging configs: Send logs to stdout for Kubernetes log aggregation

Wait for it to be ready:

```bash
kubectl -n kong wait --for=condition=Ready \
  --timeout=300s pod -l app=dataplane-with-plugin-dataplane
```

Check the logs to verify the plugin loaded:

```bash
kubectl -n kong logs -l app=dataplane-with-plugin-dataplane --tail=50
```

Look for messages like:
```
[pluginserver] starting pluginserver at: /usr/local/kong/python_pluginserver.sock
[pluginserver] plugin server started
```

✅ **Checkpoint**: Your Python plugin is now running inside Kong!

---

# Part 4: Configuration with APIOps

## Why Deck Over Kubernetes CRDs?

You might wonder: "Why not use Kubernetes CRDs like `KongService` and `KongRoute`?"

Great question! Here's why:

| Approach | Best For |
|----------|----------|
| **Deck** | Kong Gateway + Konnect (our setup) |
| **K8s CRDs** | Kong Ingress Controller (KIC) |

In our hybrid setup, **Konnect is the source of truth** for configuration. Deck manages that directly, providing:

- Version control for API configurations
- GitOps workflows
- Configuration drift detection
- Multi-environment support

## Configuring the API

Create `konnect-export.yaml`:

```yaml
_format_version: "3.0"

services:
  - name: mock-service
    url: http://httpbin.konghq.com
    routes:
      - name: mock-route
        paths:
          - /mock
        strip_path: true
        plugins:
          - name: myplugin
            config:
              message: "Hello from Python Plugin"
              header_name: "x-hello-from-python"
```

This configuration:
1. Creates a service pointing to httpbin.konghq.com
2. Routes requests from `/mock/*` to that service
3. Applies our Python plugin to the route

Apply it with Deck:

```bash
deck sync \
  --konnect-token $KONNECT_TOKEN \
  --konnect-control-plane-name gateway-control-plane \
  konnect-export.yaml
```

You should see:
```
Summary:
  Created: 3
  Updated: 0
  Deleted: 0
```

---

# Part 5: Testing Your Plugin

## The Moment of Truth

Let's test if our Python plugin actually works!

Deploy a test pod:

```bash
kubectl -n kong create deployment nginx --image=nginx
```

Get Kong's proxy IP:

```bash
export KONG_PROXY_IP=$(kubectl -n kong get svc \
  dataplane-with-plugin-dataplane-proxy \
  -o jsonpath='{.spec.clusterIP}')
```

Send a request:

```bash
kubectl -n kong exec deployment/nginx -- \
  curl -v "http://$KONG_PROXY_IP/mock/anything"
```

## What to Look For

If everything works, you'll see these custom headers in the response:

```
< HTTP/1.1 200 OK
< x-hello-from-python: Python says Hello from Python Plugin to 10.109.85.121
< x-python-pid: 2728
< Via: 1.1 kong/3.13.0.0-enterprise-edition
```

**Success!** 🎉

The `x-hello-from-python` header proves your Python code ran. The `x-python-pid` shows the process ID of the Python plugin server.

---

# Real-World Use Cases

Now that you have a working Python plugin, here are some practical use cases:

## 1. Machine Learning Integration

```python
def access(self, kong):
    # Get request data
    body = kong.request.get_raw_body()

    # Call ML model
    prediction = ml_model.predict(body)

    # Route based on prediction
    if prediction['fraud_score'] > 0.8:
        kong.response.exit(403, {"message": "Suspicious activity"})
```

## 2. Advanced Data Transformation

```python
import pandas as pd
import json

def access(self, kong):
    # Get JSON body
    body = kong.request.get_body()

    # Transform with pandas
    df = pd.DataFrame(body['data'])
    transformed = df.groupby('category').sum().to_dict()

    # Set transformed body
    kong.service.request.set_body(json.dumps(transformed))
```

## 3. Complex Business Logic

```python
def access(self, kong):
    user_id = kong.request.get_header("X-User-ID")

    # Check multiple conditions
    if not is_valid_user(user_id):
        kong.response.exit(401, {"error": "Invalid user"})

    if is_rate_limited(user_id):
        kong.response.exit(429, {"error": "Rate limit exceeded"})

    if not has_feature_access(user_id, self.config['feature']):
        kong.response.exit(403, {"error": "Feature not available"})
```

## 4. Integration with Python Services

```python
import requests

def access(self, kong):
    # Call your Python microservice
    response = requests.post(
        'http://internal-service/validate',
        json={'user': kong.request.get_header('X-User')}
    )

    if not response.json()['valid']:
        kong.response.exit(403, {"error": "Validation failed"})
```

---

# Performance Considerations

You might wonder: "Is Python slow compared to Lua?"

**Short answer**: It depends on your use case.

**Longer answer**:
- **Socket communication** adds ~1-2ms overhead
- **Python execution** varies based on your code
- **For I/O-bound operations** (API calls, database queries), the difference is negligible
- **For CPU-intensive tasks**, Lua is faster, but Python's libraries often compensate

**Best practices**:
1. **Cache aggressively**: Use Redis for frequently accessed data
2. **Async operations**: Use Python's `asyncio` for concurrent tasks
3. **Profile your code**: Use `cProfile` to identify bottlenecks
4. **Consider LuaJIT**: For hot paths, keep critical code in Lua

**Real-world numbers** from my experience:
- Simple header manipulation: ~2ms overhead
- API call + processing: Overhead is negligible (API latency dominates)
- ML inference: ~50-100ms depending on model (Python's ecosystem wins here)

---

# Debugging Tips

## View Plugin Logs

```bash
kubectl -n kong logs -l app=dataplane-with-plugin-dataplane --tail=100 -f
```

## Check Plugin Registration

```bash
kubectl -n kong exec deployment/dataplane-with-plugin-dataplane -- \
  kong plugins list | grep myplugin
```

## Test Plugin Locally

Before deploying, test your plugin standalone:

```python
# test_plugin.py
from myplugin import Plugin

config = {"message": "Test message"}
plugin = Plugin(config)

# Mock kong object for testing
class MockKong:
    # Implement mock methods
    pass

plugin.access(MockKong())
```

## Enable Debug Logging

Add to your plugin:

```python
import logging
logging.basicConfig(level=logging.DEBUG)

def access(self, kong):
    logging.debug(f"Request received: {kong.request.get_path()}")
    # Your code here
```

---

# Production Considerations

When moving to production, consider:

## 1. Error Handling

```python
def access(self, kong):
    try:
        # Your logic
        result = risky_operation()
    except Exception as e:
        # Log the error
        kong.log.err(f"Plugin error: {str(e)}")
        # Don't block the request
        return
```

## 2. Security

- Validate all inputs
- Sanitize data before external calls
- Use secrets management for credentials
- Implement rate limiting in your plugin

## 3. Monitoring

- Export metrics to Prometheus
- Set up alerts for plugin failures
- Monitor plugin server process health
- Track performance metrics

## 4. Deployment Strategy

- Use blue-green deployment for plugin updates
- Test in staging environment first
- Have rollback procedures ready
- Version your plugin images

## 5. Resource Limits

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

---

# Common Gotchas

## 1. Plugin Not Loading

**Problem**: Kong starts but plugin isn't available.

**Solution**: Check these:
- Plugin file is executable
- Python dependencies are installed
- Plugin name matches everywhere
- Socket path is correct

## 2. Certificate Issues

**Problem**: Data plane won't connect to control plane.

**Solution**:
- Verify `KonnectExtension` has automatic provisioning
- Check certificate secret exists
- Ensure correct region in `serverURL`

## 3. Configuration Not Syncing

**Problem**: Deck sync succeeds but changes aren't applied.

**Solution**:
- Wait 30 seconds for propagation
- Check Konnect UI to verify changes
- Verify control plane connection

## 4. Python Import Errors

**Problem**: Plugin can't import dependencies.

**Solution**:
- Add path to `sys.path` in `kong-pluginserver.py`:
  ```python
  sys.path.append('/usr/local/lib/python3.12/dist-packages')
  ```
- Verify dependencies in `requirements.txt`
- Rebuild Docker image

---

# What's Next?

You now have a complete, working Kong Gateway with custom Python plugins! Here are some next steps:

## Extend the Plugin

Add more phases:
```python
def header_filter(self, kong):
    # Modify response headers
    pass

def body_filter(self, kong):
    # Transform response body
    pass

def log(self, kong):
    # Custom logging
    pass
```

## Add Testing

```python
# tests/test_myplugin.py
import pytest
from myplugin import Plugin

def test_access_phase():
    plugin = Plugin({"message": "test"})
    # Test your plugin logic
    assert plugin.config['message'] == "test"
```

## Implement CI/CD

```yaml
# .github/workflows/deploy.yml
name: Deploy Plugin
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build image
        run: docker build -t my-plugin:${{ github.sha }} .
      - name: Push to registry
        run: docker push my-plugin:${{ github.sha }}
      - name: Deploy with Deck
        run: deck sync --konnect-token ${{ secrets.KONNECT_TOKEN }}
```

## Explore Advanced Features

- **Rate limiting**: Implement custom rate limiting logic
- **Caching**: Add Redis integration for caching
- **Authentication**: Create custom auth mechanisms
- **Observability**: Export custom metrics

---

# Conclusion

Building custom Kong Gateway plugins with Python opens up a world of possibilities. You get:

✅ Kong's performance and reliability
✅ Python's ecosystem and flexibility
✅ Kubernetes-native deployment
✅ GitOps-friendly configuration
✅ Enterprise-grade management with Konnect

The architecture we built today is production-ready and scalable. You can:

- Deploy in multiple regions
- Scale data planes independently
- Manage configuration as code
- Leverage Python's rich ecosystem

## Key Takeaways

1. **Python plugins run in separate processes**, communicating via Unix sockets
2. **Hybrid deployment** separates control plane (config) from data plane (traffic)
3. **Deck provides declarative configuration** management for GitOps
4. **The Gateway Operator** makes Kubernetes deployment straightforward
5. **Performance overhead is minimal** for most use cases

## Get the Code

All code from this tutorial is available on GitHub:

👉 **[github.com/your-username/kong-python-plugin-example](https://github.com)**

Star the repo if you found this helpful!

## Connect

Have questions or want to share what you built? Let's connect:

- Twitter: [@yourusername](https://twitter.com)
- LinkedIn: [Your Profile](https://linkedin.com)
- GitHub: [@yourusername](https://github.com)

Or leave a comment below — I read and respond to all of them!

---

## Further Reading

- [Kong Plugin Development Guide](https://docs.konghq.com/gateway/latest/plugin-development/)
- [Kong Python PDK Documentation](https://docs.konghq.com/gateway/latest/plugin-development/pdk/python/)
- [Kong Gateway Operator Docs](https://docs.konghq.com/gateway-operator/latest/)
- [Deck Best Practices](https://docs.konghq.com/deck/latest/guides/best-practices/)

---

*Thanks for reading! If you found this helpful, please clap 👏 and share with your network. Happy coding!*

---

**Tags**: #Kong #KongGateway #Python #Kubernetes #APIOps #DevOps #CloudNative #Microservices #APIManagement #Tutorial
