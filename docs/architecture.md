# Architecture

## Goal

Simulate an enterprise delivery platform on a 32 GB Mac while keeping the
business workloads intentionally small. The value of this lab is that both the
local preview path and the GitOps path are exercised from the same repository:

```text
local code -> GitHub -> GitHub Actions
  -> preview deploy to local Mac stack
  -> GHCR -> GitOps repo path -> Argo CD
  -> Argo Rollouts -> APISIX -> K3s workloads -> Prometheus/Grafana/Loki
```

## Components

- k3d/K3s: lightweight local Kubernetes running on Docker Desktop.
- GitHub Actions: CI runner for test, build, and image push.
- Self-hosted macOS runner: local `dev/test/prod` environment deployment.
- GHCR: container registry.
- Argo CD: pull-based GitOps deployment.
- Argo Rollouts: canary rollout controller.
- APISIX: gateway, routing, and rate limiting.
- Prometheus/Grafana: metrics and dashboards.
- Loki: log storage.
- Spring Boot Admin: local service health and actuator inspection.

## Business Scope

The sample workloads are split into two tracks:

- k3d / GitOps track:
  - `blog-web`: static UI.
  - `blog-api`: small Spring Boot HTTP API with Actuator and Micrometer.
- local-first CI / preview track:
  - `admin-server`: Spring Boot Admin.
  - `api-gateway`: local gateway entrypoint.
  - `user-service` and `order-service`: downstream reference services.

This keeps the Kubernetes path lightweight while still giving the repository a
more realistic multi-service engineering surface.

## First Deployment Milestones

1. Verify the root Maven reactor with `./mvnw -B -ntp verify`.
2. Bring up the local reference services with `make dev-up`.
3. Install the local k3d cluster.
4. Install Argo CD and Argo Rollouts.
5. Install APISIX.
6. Publish images to GHCR.
7. Deploy the blog workloads through Argo CD.
8. Add Prometheus/Grafana/Loki/SkyWalking.
9. Run preview, canary, rollback, and rate-limit drills.
