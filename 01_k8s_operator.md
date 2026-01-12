# To Install

## Start minikube

minikube start

## Set context

minikube update-context
kubectl config current-context
kubectl config set-context --current --namespace=kong

## Set kubectl alias

alias k=kubectl

## VALIDATE_IMAGES and GATEWAY_OPERATOR_VALIDATE_IMAGES -> to allow kong operator controller to load custom image

helm upgrade --install kong-operator kong/kong-operator -n kong-system \
  --create-namespace \
  --set image.tag=2.0.5 \
  --set env.ENABLE_CONTROLLER_KONNECT=true \
  --set env.VALIDATE_IMAGES=false \
  --set env.GATEWAY_OPERATOR_VALIDATE_IMAGES=false

### If just update

helm upgrade kong-operator kong/kong-operator -n kong-system \
  --set image.tag=2.0.5 \
  --set env.ENABLE_CONTROLLER_KONNECT=true \
  --set env.VALIDATE_IMAGES=false \
  --set env.GATEWAY_OPERATOR_VALIDATE_IMAGES=false 

## Verify

kubectl -n kong-system wait --for=condition=Available=true --timeout=120s deployment/kong-operator-kong-operator-controller-manager

kubectl -n kong-system get all 