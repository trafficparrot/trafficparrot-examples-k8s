# Traffic Parrot on Kubernetes

Helm charts that run Traffic Parrot, and the Traffic Parrot License Server, on any Kubernetes cluster
with an Ingress controller. They are tested with [ingress-nginx](https://kubernetes.github.io/ingress-nginx/).

| Directory | What it is |
|---|---|
| `trafficparrot-image/` | Dockerfile for a Traffic Parrot image |
| `trafficparrot-chart/` | Helm chart: a Deployment, a Service and three Ingresses (UI, HTTP virtual service, gRPC virtual service) |
| `licenseserver-image/` | Dockerfile for a License Server image |
| `licenseserver-chart/` | Helm chart: a Deployment, a Service, two Ingresses (UI, usage) and optionally a PersistentVolumeClaim |

For OpenShift, use the OpenShift charts in [trafficparrot-examples-helm](https://github.com/trafficparrot/trafficparrot-examples-helm).
Coming from those charts, read the "Upgrading from the OpenShift chart" section of each chart's README.

## Prerequisites

- Kubernetes with `networking.k8s.io/v1` Ingress, and Helm 3.10 or later (the install commands below use `--set-json`).
- ingress-nginx. The License Server's usage Ingress needs the controller started with
  `--enable-ssl-passthrough`. Another controller needs its own equivalents of the two ingress-nginx
  annotations the charts set by default (`backend-protocol: GRPC` and `ssl-passthrough`); set them in
  the `ingress.*.annotations` values.
- A private registry your cluster can pull from. The License Server image carries its license.
- DNS names for the Ingress hosts, pointing at your Ingress controller.

## Traffic Parrot

Build the image from a Traffic Parrot release zip:

```bash
cp trafficparrot-linux-x64-jre-*.zip ./trafficparrot-image/
unzip -p ./trafficparrot-image/trafficparrot-*.zip '*/trafficparrot.properties' > ./trafficparrot-image/trafficparrot.properties
# edit ./trafficparrot-image/trafficparrot.properties if you need to, then:
docker build -t registry.example.com/trafficparrot:5.x ./trafficparrot-image
docker push registry.example.com/trafficparrot:5.x
```

Keep the license out of the image: store it, base64-encoded, in a Secret.

```bash
kubectl create namespace trafficparrot
kubectl --namespace trafficparrot create secret generic trafficparrot-license \
    --from-literal=license="$(base64 < trafficparrot.license | tr -d '\n')"
```

gRPC through ingress-nginx needs TLS at the controller, so give the gRPC host a certificate:

```bash
kubectl --namespace trafficparrot create secret tls trafficparrot-tls --cert=tls.crt --key=tls.key
```

Install:

```bash
helm install trafficparrot ./trafficparrot-chart --namespace trafficparrot \
    --set image=registry.example.com/trafficparrot:5.x \
    --set license.existingSecret=trafficparrot-license \
    --set ingress.ui.host=trafficparrot-ui.example.com \
    --set ingress.httpvs.host=trafficparrot-http-vs.example.com \
    --set ingress.grpcvs.host=trafficparrot-grpc-vs.example.com \
    --set-json 'ingress.tls=[{"secretName":"trafficparrot-tls","hosts":["trafficparrot-ui.example.com","trafficparrot-grpc-vs.example.com"]}]' \
    --wait
```

Then:
- the UI is at `https://trafficparrot-ui.example.com/`;
- HTTP virtual services are at `http://trafficparrot-http-vs.example.com/`;
- gRPC virtual services are at `trafficparrot-grpc-vs.example.com:443`, over TLS.

## Traffic Parrot License Server

Build the image from a License Server release zip and your `trafficparrot.usage.license`:

```bash
cp trafficparrot-license-usage-linux-x64-jre-*.zip trafficparrot.usage.license ./licenseserver-image/
unzip -p ./licenseserver-image/trafficparrot-license-usage-*.zip '*/licenseusage.properties' > ./licenseserver-image/licenseusage.properties
docker build -t registry.example.com/trafficparrot-license-usage:1.x ./licenseserver-image
docker push registry.example.com/trafficparrot-license-usage:1.x
```

Install. `localdev=false` keeps the License Server's data on a PersistentVolume, from the cluster's
default StorageClass unless you name one with `storageclass`:

```bash
helm install trafficparrot-license-usage ./licenseserver-chart \
    --namespace trafficparrot-license-usage --create-namespace \
    --set image=registry.example.com/trafficparrot-license-usage:1.x \
    --set localdev=false \
    --set ingress.ui.host=trafficparrot-license-ui.example.com \
    --set ingress.usage.host=trafficparrot-license-usage.example.com \
    --wait
```

Point Traffic Parrot at the usage Ingress with
`trafficparrot.license.usage.server=https://trafficparrot-license-usage.example.com` in its
`trafficparrot.properties`. The usage Ingress passes TLS straight through, so the License Server's own
certificate is the one Traffic Parrot sees.
