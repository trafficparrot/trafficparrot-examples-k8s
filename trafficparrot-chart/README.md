# traffic-parrot chart

Traffic Parrot on Kubernetes: a Deployment, a Service with the named ports `ui-port`, `http-vs-port`
and `grpc-vs-port`, and one Ingress for each. Installation steps are in the [README](../README.md) one
level up.

## Values

| Value | Default | Meaning |
|---|---|---|
| `appid` | `trafficparrot` | Name of every object, and its `app` label |
| `image` | `trafficparrot:latest` | The image built from `../trafficparrot-image` |
| `imagePullPolicy` | `Always` | |
| `uiport`, `httpvsport`, `grpcvsport` | `8080`, `8081`, `5552` | Container ports; must match the image's `trafficparrot.properties` |
| `license.existingSecret` | `""` | A Secret holding the base64-encoded license, read through the `TRAFFICPARROT_LICENSE` environment variable. Empty: the image's `trafficparrot.license` |
| `license.key` | `license` | The key in that Secret |
| `resources` | `{}` | Container resources |
| `command` | `[]` | Container command |
| `ingress.className` | `nginx` | The IngressClass; empty uses the cluster default |
| `ingress.tls` | `[]` | Shaped like an Ingress's `spec.tls`; each Ingress takes the entries covering its host, by exact name or a wildcard one label above it (`*.example.com`). An entry that covers none of the hosts fails the install |
| `ingress.ui.host` | `trafficparrot-ui.example.com` | Host of the UI Ingress |
| `ingress.httpvs.host` | `trafficparrot-http-vs.example.com` | Host of the HTTP virtual service Ingress |
| `ingress.grpcvs.host` | `trafficparrot-grpc-vs.example.com` | Host of the gRPC virtual service Ingress |
| `ingress.*.annotations` | UI: `nginx.ingress.kubernetes.io/force-ssl-redirect: "true"`; HTTP virtual service: `{}`; gRPC: `nginx.ingress.kubernetes.io/backend-protocol: GRPC` | Annotations of each Ingress |

Helm merges the annotations you set into the defaults. To remove a default one, set it to `null`, for
example `--set 'ingress.grpcvs.annotations.nginx\.ingress\.kubernetes\.io/backend-protocol=null'`.

## Upgrading from the OpenShift chart (1.0.0)

**2.0.0 is a breaking change.** The OpenShift Routes are now Ingresses, and an Ingress has no TLS
termination mode, so `uitermination` and `vstermination` are removed. Passing either fails the
install, naming the replacement, rather than being silently ignored.

| 1.0.0 | 2.0.0 |
|---|---|
| `uitermination=edge` | An `ingress.tls` entry naming `ingress.ui.host`. TLS ends at the Ingress controller |
| `uitermination=passthrough` | `uiport=8079` (Traffic Parrot's HTTPS UI port) and the `nginx.ingress.kubernetes.io/ssl-passthrough: "true"` annotation in `ingress.ui.annotations` |
| `uitermination=reencrypt` | `uiport=8079`, an `ingress.tls` entry, and `nginx.ingress.kubernetes.io/backend-protocol: HTTPS` in `ingress.ui.annotations` |
| `vstermination=edge` | `ingress.tls` entries naming the virtual service hosts |
| `vstermination=passthrough` | Traffic Parrot's TLS ports, `httpvsport=8082` and `grpcvsport=5551`, with the `ssl-passthrough` annotation on both Ingresses. Port 5551 requires client certificates by default (`trafficparrot.virtualservice.grpc.requireClientAuthentication`) |
| `vstermination=reencrypt` | The same TLS ports, `ingress.tls` entries, and `backend-protocol: HTTPS` (HTTP) or `GRPCS` (gRPC). For 5551, ingress-nginx is the gRPC client, so it also needs a client certificate Traffic Parrot trusts, through `nginx.ingress.kubernetes.io/proxy-ssl-secret` |
| `insecureEdgeTerminationPolicy: None` (fixed) | The UI Ingress's default `force-ssl-redirect` annotation redirects plain HTTP to HTTPS. ingress-nginx also redirects any host with an `ingress.tls` entry |
| Objects in a namespace named after `appid` | Objects in the release namespace, `helm install --namespace` |
| The license copied into the image | `license.existingSecret` |

1.0.0's default, `vstermination=passthrough`, sent TLS to the plaintext ports 8081 and 5552. 2.0.0's
defaults serve the HTTP virtual service over plain HTTP, end the gRPC virtual service's TLS at the
controller, and redirect the UI to HTTPS. Until you add an `ingress.tls` entry, HTTPS uses
ingress-nginx's default certificate.
