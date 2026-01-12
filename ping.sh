export KONNECT_TOKEN=xxx

deck gateway ping \
  --konnect-control-plane-name="gateway-control-plane" \
  --konnect-addr="https://sg.api.konghq.com" \
  --konnect-token="$KONNECT_TOKEN"