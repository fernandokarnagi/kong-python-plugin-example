https://developer.konghq.com/operator/dataplanes/get-started/hybrid/deploy-dataplane/

export KONNECT_TOKEN=xxxxx

echo '
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
          name: gateway-control-plane' | kubectl apply -f -

---

# Build the customer docker image
docker build -t konggtwpythonplugin:0.0.1 -f Dockerfile .

# in Minikube, we need to load that image into Minikube image registry, to avoid pulling
minikube image load konggtwpythonplugin:0.0.1

# Remember to load the KONG_PLUGINS
# Refer https://developer.konghq.com/gateway/configuration/ and https://developer.konghq.com/gateway/manage-kong-conf/#environment-variables you can manage all Kong Gateway configuration parameters using environment variables.

# Pre-requisites
you need to create a schema.lua file even for Python plugins.

  Kong's core is written in Lua, and it needs a Lua schema to:
  1. Validate plugin configurations via the Admin API
  2. Register the plugin in Kong's database
  3. Provide schema information for the Control Plane

---

echo '
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

' | kubectl apply -f -

---
