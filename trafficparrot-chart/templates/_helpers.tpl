{{/*
"true" when a host is one of the given TLS hosts, exactly or under a wildcard one label above it
(as TLS certificates match: *.example.com covers ui.example.com, not a.ui.example.com); else empty.
Usage: include "traffic-parrot.tlsCovers" (dict "host" $host "hosts" $entry.hosts)
*/}}
{{- define "traffic-parrot.tlsCovers" -}}
{{- $host := .host -}}
{{- range .hosts -}}
{{- if or (eq . $host) (and (hasPrefix "*." .) (contains "." $host) (eq (trimPrefix "*." .) (regexReplaceAll "^[^.]+\\." $host ""))) -}}
true
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
One Ingress to the Service's named port, carrying the ingress.tls entries that cover its host.
Usage: include "traffic-parrot.ingress" (dict "root" $ "suffix" "ui" "port" "ui-port" "ingress" .Values.ingress.ui "key" "ingress.ui.host")
*/}}
{{- define "traffic-parrot.ingress" -}}
{{- $values := .root.Values -}}
{{- $host := required (printf "%s is required: each Ingress needs its own host" .key) .ingress.host -}}
{{- $tls := list -}}
{{- range $values.ingress.tls -}}
{{- if include "traffic-parrot.tlsCovers" (dict "host" $host "hosts" .hosts) -}}
{{- $tls = append $tls . -}}
{{- end -}}
{{- end -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $values.appid }}-{{ .suffix }}
  namespace: {{ .root.Release.Namespace }}
  labels:
    app: {{ $values.appid }}
  {{- with .ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with $values.ingress.className }}
  ingressClassName: {{ . }}
  {{- end }}
  {{- with $tls }}
  tls:
    {{- toYaml . | nindent 2 }}
  {{- end }}
  rules:
  - host: {{ $host | quote }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ $values.appid }}
            port:
              name: {{ .port }}
{{- end -}}
