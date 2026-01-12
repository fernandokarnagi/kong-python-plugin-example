# Step 1: Install Kong Gateway Operator

This guide walks through setting up a local Kubernetes cluster with Minikube and installing the Kong Gateway Operator with Konnect integration enabled.

## Prerequisites

- [Minikube](https://minikube.sigs.k8s.io/docs/start/) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [Helm 3](https://helm.sh/docs/intro/install/) installed
- At least 4GB of RAM available for Minikube

## Step 1.1: Start Minikube

Start your local Kubernetes cluster with Minikube:

```bash
minikube start
```

This command will:
- Create a local Kubernetes cluster
- Configure kubectl to connect to it
- Start the necessary cluster components

## Step 1.2: Configure Kubernetes Context

Update your Kubernetes context and set the default namespace:

```bash
# Update context
minikube update-context

# Verify current context
kubectl config current-context

# Set default namespace to 'kong' for convenience
kubectl config set-context --current --namespace=kong
```

## Step 1.3: Set kubectl Alias (Optional)

For convenience, create a short alias for kubectl:

```bash
alias k=kubectl
```

Add this to your shell configuration file (`~/.bashrc`, `~/.zshrc`, etc.) to make it permanent.

## Step 1.4: Add Kong Helm Repository

Add the Kong Helm chart repository:

```bash
helm repo add kong https://charts.konghq.com
helm repo update
```

## Step 1.5: Install Kong Gateway Operator

Install the Kong Gateway Operator with Konnect support and custom image validation disabled:

```bash
helm upgrade --install kong-operator kong/kong-operator -n kong-system \
  --create-namespace \
  --set image.tag=2.0.5 \
  --set env.ENABLE_CONTROLLER_KONNECT=true \
  --set env.VALIDATE_IMAGES=false \
  --set env.GATEWAY_OPERATOR_VALIDATE_IMAGES=false
```

### Configuration Options Explained

- `--create-namespace`: Creates the `kong-system` namespace if it doesn't exist
- `image.tag=2.0.5`: Specifies the Kong Gateway Operator version
- `env.ENABLE_CONTROLLER_KONNECT=true`: Enables Kong Konnect integration
- `env.VALIDATE_IMAGES=false`: Disables image validation to allow custom Kong images
- `env.GATEWAY_OPERATOR_VALIDATE_IMAGES=false`: Disables Gateway Operator image validation

**Why disable image validation?**
We're building a custom Kong Gateway image with Python plugin support. The validation would reject our custom image, so we need to disable it. In production, you should carefully validate your custom images through your own CI/CD pipeline.

### Updating an Existing Installation

If the operator is already installed and you just need to update it:

```bash
helm upgrade kong-operator kong/kong-operator -n kong-system \
  --set image.tag=2.0.5 \
  --set env.ENABLE_CONTROLLER_KONNECT=true \
  --set env.VALIDATE_IMAGES=false \
  --set env.GATEWAY_OPERATOR_VALIDATE_IMAGES=false
```

## Step 1.6: Verify Installation

Wait for the operator deployment to be ready:

```bash
kubectl -n kong-system wait --for=condition=Available=true --timeout=120s \
  deployment/kong-operator-kong-operator-controller-manager
```

Check that all resources are running properly:

```bash
kubectl -n kong-system get all
```

You should see output similar to:

```
NAME                                                                READY   STATUS    RESTARTS   AGE
pod/kong-operator-kong-operator-controller-manager-xxxxx-xxxxx     2/2     Running   0          2m

NAME                                                                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/kong-operator-kong-operator-controller-manager-metrics-service   ClusterIP   10.96.xxx.xxx   <none>        8443/TCP   2m

NAME                                                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/kong-operator-kong-operator-controller-manager   1/1     1            1           2m
```

## Troubleshooting

### Minikube Won't Start

If Minikube fails to start:

```bash
# Delete and recreate the cluster
minikube delete
minikube start --memory=4096 --cpus=2
```

### Operator Pod Not Running

Check the operator logs:

```bash
kubectl -n kong-system logs deployment/kong-operator-kong-operator-controller-manager -c manager
```

### Helm Installation Fails

Verify Helm can connect to your cluster:

```bash
helm list -n kong-system
```

If you see connection errors, check your kubectl context:

```bash
kubectl config current-context
kubectl cluster-info
```

## What's Next?

Now that the Kong Gateway Operator is installed, proceed to:

**[Step 2: Create Control Plane in Kong Konnect →](./02_create_control_plane.md)**

This will configure the connection to Kong Konnect and create a control plane for managing your Gateway configuration.

## Additional Resources

- [Kong Gateway Operator Documentation](https://docs.konghq.com/gateway-operator/latest/)
- [Kong Gateway Operator Installation Guide](https://docs.konghq.com/gateway-operator/latest/install/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Helm Documentation](https://helm.sh/docs/) 