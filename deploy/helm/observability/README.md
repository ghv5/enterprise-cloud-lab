# Local Observability

These assets make the local `k3d` lab self-contained.

Included components:

- `kube-prometheus-stack` for Prometheus and Grafana
- `loki` for log storage
- `alloy` for Kubernetes pod log collection
- `observability-addons` for APISIX `ServiceMonitor` and Grafana Loki datasource
- `observability-tracing` for SkyWalking OAP and UI

Primary entry points:

- `infra/local-k3d/install-observability.sh`
- `infra/local-k3d/install-skywalking.sh`
- `infra/local-k3d/port-forward-grafana.sh`
- `infra/local-k3d/port-forward-prometheus.sh`
- `infra/local-k3d/port-forward-skywalking.sh`
