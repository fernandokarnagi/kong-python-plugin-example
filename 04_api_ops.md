# Use Deck for APIOps

why? coz of single of truth for API definition has to be at Kong, not K8S ETC, so cannot use CRD.
CRD is recommended for KIC.

## ping

```
./ping.sh
```

## dump config

```
./dump_config.sh
```

## sync config

```
./sync_config.sh
```

## Verify

### Deploy nginx pod for accessing gateway cluster IP from within

```
kubectl -n kong create deployment nginx --image=nginx
```

### Execute the curl from within the nginx pod

```
kubectl -n kong exec pod/nginx-66686b6766-zztnc -- curl -v "http://10.109.85.121/mock/anything" --no-progress-meter --fail-with-body --insecure
```

>>>

Notice that the x-hello-from-python and x-python-pid headers are returned into Response header, which means the Plugin works

```
*   Trying 10.109.85.121:80...
* Connected to 10.109.85.121 (10.109.85.121) port 80
* using HTTP/1.x
> GET /mock/anything HTTP/1.1
> Host: 10.109.85.121
> User-Agent: curl/8.14.1
> Accept: */*
> 
* Request completely sent off
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
    "X-Forwarded-Prefix": "/mock", 
    "X-Kong-Request-Id": "e1a6ee290dbdfc5ffcee113ced85cb06"
  }, 
  "json": null, 
  "method": "GET", 
  "origin": "10.244.0.13", 
  "url": "http://10.109.85.121/anything"
}
< HTTP/1.1 200 OK
< Content-Type: application/json
< Content-Length: 497
< Connection: keep-alive
< x-hello-from-python: Python says Hello from Python Plugin to 10.109.85.121
< x-python-pid: 2728
< Server: gunicorn/19.9.0
< Date: Mon, 12 Jan 2026 12:11:39 GMT
< Access-Control-Allow-Origin: *
< Access-Control-Allow-Credentials: true
< X-Kong-Upstream-Latency: 1104
< X-Kong-Proxy-Latency: 186
< Via: 1.1 kong/3.13.0.0-enterprise-edition
< X-Kong-Request-Id: e1a6ee290dbdfc5ffcee113ced85cb06
< 
{ [497 bytes data]
* Connection #0 to host 10.109.85.121 left intact

```