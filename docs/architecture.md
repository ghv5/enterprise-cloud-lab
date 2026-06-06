# Architecture

## Goal

Simulate an enterprise deployment platform on a 32 GB Mac while keeping the
business application small. The value of this lab is the release path:

```text
local code -> GitHub -> GitHub Actions -> GHCR -> GitOps repo path -> Argo CD
  -> Argo Rollouts -> APISIX -> K3s workloads -> Prometheus/Grafana/Loki
```

## Components

- k3d/K3s: lightweight local Kubernetes running on Docker Desktop.
- GitHub Actions: CI runner for test, build, and image push.
- GHCR: container registry.
- Argo CD: pull-based GitOps deployment.
- Argo Rollouts: canary rollout controller.
- APISIX: gateway, routing, and rate limiting.
- Prometheus/Grafana: metrics and dashboards.
- Loki: log storage.

## Business Scope

The sample business system is intentionally limited:

- `blog-web`: static UI.
- `blog-api`: small Spring Boot HTTP API with Actuator and Micrometer.

This keeps cluster capacity available for platform middleware and release
experiments.

## First Deployment Milestones

1. Bring up the local k3d cluster.
2. Install Argo CD and Argo Rollouts.
3. Install APISIX.
4. Publish `blog-api` and `blog-web` images to GHCR.
5. Deploy apps through Argo CD.
6. Add Prometheus/Grafana/Loki.
7. Run canary, rollback, and rate-limit drills.
