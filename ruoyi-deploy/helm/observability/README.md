# Observability

This directory stores the Helm values, vendored chart packages, and runbook for
the local observability stack.

Scope of the first slice:

- `kube-prometheus-stack` for Prometheus, Alertmanager, and Grafana
- `loki` for log storage
- `alloy` for pod log collection
- project-native metrics and dashboards:
  - Spring Boot `/actuator/prometheus`
  - Nacos `/nacos/actuator/prometheus`
  - APISIX `/apisix/prometheus/metrics`
  - existing Grafana dashboards from `RuoYi-Cloud-Plus/script/config/grafana`

## Files

- `kube-prometheus-stack.values.yaml`
- `loki.values.yaml`
- `alloy.values.yaml`
- `charts/`

## Install sequence

1. Install Prometheus and Grafana:

```bash
helm upgrade --install kube-prometheus-stack kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  -n observability \
  -f deploy/helm/observability/kube-prometheus-stack.values.yaml
```

2. Install Loki:

```bash
helm upgrade --install loki loki \
  --repo https://grafana.github.io/helm-charts \
  -n observability \
  -f deploy/helm/observability/loki.values.yaml
```

3. Install Alloy:

```bash
helm upgrade --install alloy deploy/helm/observability/charts/alloy-1.8.2.tgz \
  -n observability \
  -f deploy/helm/observability/alloy.values.yaml
```

4. Enable backend `ServiceMonitor` resources:

```bash
helm upgrade ruoyi-backend deploy/helm/ruoyi-backend \
  -n ruoyi \
  --reuse-values \
  --set global.serviceMonitor.enabled=true \
  --set global.serviceMonitor.basicAuth.enabled=true
```

## Required follow-up

Before step 4, create the Basic Auth Secret used by the backend
`ServiceMonitor`. The current actuator credentials are the same credentials
already used by the health probes.

```bash
/Applications/Docker.app/Contents/Resources/bin/kubectl create secret generic ruoyi-actuator-basic-auth \
  -n ruoyi \
  --from-literal=username=ruoyi \
  --from-literal=password=123456
```

## Metrics targets to wire

- `ruoyi-backend-*` services:
  - path: `/actuator/prometheus`
  - auth: Basic Auth required
- `release-platform-infra-nacos.infra.svc.cluster.local:8848`
  - path: `/nacos/actuator/prometheus`
  - auth: `ruoyi / 123456`
- `apisix-prometheus-metrics.apisix.svc.cluster.local:9091`
  - path: `/apisix/prometheus/metrics`
  - auth: none

## Verification

- `kubectl get pods -n observability`
- `kubectl get servicemonitor -A`
- `kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80`
- `kubectl port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090`
- `kubectl port-forward -n observability svc/loki 3100:3100`

## Notes

- The backend metrics path is protected, so Prometheus scraping depends on the
  `ruoyi-actuator-basic-auth` Secret.
- SkyWalking is intentionally left for the next slice. It needs agent
  distribution and JVM injection, which is separate from metrics and logs.
- Log collection uses `Grafana Alloy` instead of `Promtail`. This follows the
  current Grafana chart direction and avoids depending on a deprecated chart.
- On Docker Desktop Kubernetes, `node-exporter` is excluded from the local
  stack because the host root mount is not shared/slave and the container keeps
  CrashLooping.
- The first direct install attempt for `kube-prometheus-stack` timed out while
  reaching `https://prometheus-community.github.io/helm-charts`. If this
  persists, use the same approach as `traffic-gateway`: vendor the required
  chart tarballs locally and install from disk. The current local copies are:
  - `charts/kube-prometheus-stack-86.1.1.tgz`
  - `charts/loki-7.0.0.tgz`
  - `charts/alloy-1.8.2.tgz`
