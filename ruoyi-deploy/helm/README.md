# Helm Deployment Layout

This directory stores Kubernetes deployment assets managed by Helm.

## Layout

- `platform-infra`: MySQL, Redis, Kafka, and custom Nacos deployment.
- `traffic-gateway`: APISIX, APISIX Ingress Controller, and route resources.
- `observability`: Prometheus, Grafana, Loki, Promtail, and SkyWalking.
- `ruoyi-backend`: RuoYi Java services.
- `ruoyi-frontend`: `ruoyi-plus-soybean` frontend service.

## Rules

- Prefer not to vendor third-party chart tarballs here. The current exception is
  `traffic-gateway/charts/apisix-2.11.2.tgz`, kept only because the local lab
  network was timing out against the upstream chart source.
- `observability/charts/*.tgz` is the second intentional exception for the same
  reason. These packages are deployment inputs, not runtime artifacts.
- Keep runtime data, logs, and build artifacts out of this tree.
- Use `values-*.yaml` for environment-specific overrides.

## Current State

- `platform-infra` is a self-contained chart and is deployed in the local `infra` namespace.
- `traffic-gateway` is deployed in the local `apisix` namespace and exposes APISIX on `http://127.0.0.1:30080`.
- `ruoyi-backend` contains the first concrete backend chart.
- `ruoyi-frontend` contains the first concrete frontend chart.
- `observability` now stores the Helm values and install notes for Prometheus, Grafana, Loki, and log collection.
- The local `docker-desktop` Kubernetes API was reachable and the node was `Ready` when checked on 2026-06-04.
