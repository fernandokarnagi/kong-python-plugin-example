export KONNECT_TOKEN=xxxx

  deck gateway dump \
  --konnect-control-plane-name="gateway-control-plane" \
  --konnect-addr="https://sg.api.konghq.com" \
  --konnect-token="$KONNECT_TOKEN" \
  -o konnect-export.yaml