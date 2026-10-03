# traffic-parrot-license-server chart

The Traffic Parrot License Server on Kubernetes: a Deployment, a Service with the named ports
`ui-port` and `usage-port`, one Ingress for each, and a PersistentVolumeClaim for its data unless
`localdev` is true. Installation steps are in the [README](../README.md) one level up.

## Values

| Value | Default | Meaning |
|---|---|---|
| `appid` | `trafficparrot-license-usage` | Name of every object, and its `app` label |
| `image` | `trafficparrot-license-usage:latest` | The image built from `../licenseserver-image` |
| `imagePullPolicy` | `Always` | |
| `uiport`, `usageport` | `8050`, `8040` | Container ports; must match the image's `licenseusage.properties` |
| `localdev` | `true` | `true` keeps the data in an emptyDir, lost with the pod; `false` claims a PersistentVolume |
| `storage` | `1Gi` | Size of that claim |
| `storageclass` | `""` | StorageClass of that claim; empty uses the cluster default |
| `resources` | `{}` | Container resources |
| `command` | `[]` | Container command |
| `ingress.className` | `nginx` | The IngressClass; empty uses the cluster default |
| `ingress.tls` | `[]` | Shaped like an Ingress's `spec.tls`; each Ingress takes the entries covering its host, by exact name or a wildcard one label above it (`*.example.com`). An entry that covers none of the hosts fails the install |
| `ingress.ui.host` | `trafficparrot-license-ui.example.com` | Host of the UI Ingress |
| `ingress.usage.host` | `trafficparrot-license-usage.example.com` | Host of the usage Ingress |
| `ingress.*.annotations` | UI: `nginx.ingress.kubernetes.io/force-ssl-redirect: "true"`; usage: `nginx.ingress.kubernetes.io/ssl-passthrough: "true"` | Annotations of each Ingress |

The usage port serves TLS itself (`license.usage.port.ssl.enabled=true`), so its Ingress passes the TLS
connection through, which needs ingress-nginx started with `--enable-ssl-passthrough`. To remove a
default annotation, set it to `null`.

The License Server reads its `trafficparrot.usage.license` from a file only, so
`../licenseserver-image` copies it into the image. Push that image to a private registry.

## Upgrading from the OpenShift chart (1.0.0)

**2.0.0 is a breaking change.** The OpenShift Routes are now Ingresses, and an Ingress has no TLS
termination mode, so `uitermination` and `usagetermination` are removed. Passing either fails the
install, naming the replacement, rather than being silently ignored.

| 1.0.0 | 2.0.0 |
|---|---|
| `uitermination=edge` | An `ingress.tls` entry naming `ingress.ui.host`. TLS ends at the Ingress controller |
| `uitermination=passthrough` | `uiport=8051` (the HTTPS UI port) and the `nginx.ingress.kubernetes.io/ssl-passthrough: "true"` annotation in `ingress.ui.annotations` |
| `uitermination=reencrypt` | `uiport=8051`, an `ingress.tls` entry, and `nginx.ingress.kubernetes.io/backend-protocol: HTTPS` in `ingress.ui.annotations` |
| `usagetermination=passthrough` | The default: the `ssl-passthrough` annotation in `ingress.usage.annotations` |
| `insecureEdgeTerminationPolicy: None` (fixed) | The UI Ingress's default `force-ssl-redirect` annotation redirects plain HTTP to HTTPS. ingress-nginx also redirects any host with an `ingress.tls` entry |
| `storageclass: example` | `storageclass: ""`, the cluster's default StorageClass |
| `port: 5552` | Removed; no template read it |
| Objects in a namespace named after `appid` | Objects in the release namespace, `helm install --namespace` |
