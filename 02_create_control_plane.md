# Reference
https://developer.konghq.com/operator/konnect/crd/control-planes/hybrid/

export KONNECT_TOKEN=xxxxxxx

kubectl create namespace kong --dry-run=client -o yaml | kubectl apply -f -

echo '
kind: KonnectAPIAuthConfiguration
apiVersion: konnect.konghq.com/v1alpha1
metadata:
  name: konnect-api-auth
  namespace: kong
spec:
  type: token
  token: "'$KONNECT_TOKEN'"
  serverURL: sg.api.konghq.com
' | kubectl apply -f -

---

echo '
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
' | kubectl apply -f -

---

kubectl get -n kong konnectgatewaycontrolplane gateway-control-plane \
  -o=jsonpath='{.status.conditions[?(@.type=="Programmed")]}' | jq

>>>
{
  "lastTransitionTime": "2026-01-08T11:29:33Z",
  "message": "",
  "observedGeneration": 1,
  "reason": "Programmed",
  "status": "True",
  "type": "Programmed"
}

---
