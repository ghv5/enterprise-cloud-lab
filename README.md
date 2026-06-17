# Enterprise Cloud Lab

This repository is a local-first enterprise delivery lab. It combines a
lightweight k3d + GitOps playground with a Java microservice engineering
scaffold, so CI, preview environments, self-hosted runner CD, canary release,
rollback, rate limiting, and observability can all be exercised in one place.

## Directory Layout

```text
apps/
  admin-server/          # Spring Boot Admin sample for local-first service operations
  api-gateway/           # Spring Cloud Gateway entrypoint for the reference services
  blog-api/              # Minimal Spring Boot API used for rollout and metrics demos
  blog-web/              # Static blog frontend served by Nginx
  order-service/         # Sample downstream service for local preview and smoke checks
  user-service/          # Sample downstream service for local preview and smoke checks
ci/
  github-actions/        # GitHub Actions workflow templates
docs/
  architecture.md        # Target architecture and sizing
  engineering/           # CI / preview / runner workflow notes
  local-runbook.md       # Local Mac workflow
  ops/                   # Operations and troubleshooting notes
  runbook.md             # Deployment, canary, rollback, and verification flow
deploy/
  argocd/                # Argo CD Application manifests
  helm/                  # Helm charts for the sample apps
  apisix/                # APISIX route and rate-limit examples
infra/
  local-k3d/             # Local Mac cluster scripts
  k3s/                   # Optional three-node cloud K3s planning notes
  scripts/               # Optional cloud install command templates
ops/
  docker/                # Local preview and observability compose assets
  environments/          # dev / test / prod local environment baselines
platform/
  common-core/           # Shared API envelope and business exception primitives
  common-web/            # Shared requestId filter and exception handler
scripts/
  stack-up.sh            # Starts the local reference service stack
  stack-down.sh          # Stops the local reference service stack
  smoke-check.sh         # Smoke tests the local gateway and services
```

## Repository

GitHub repository:

```text
https://github.com/ghv5/enterprise-cloud-lab.git
```

Treat this directory as the repository root when pushing to GitHub.

## Recommended First Cluster

- Local machine: 32 GB Mac Pro.
- Docker Desktop resources: 8 CPU, 18-22 GB RAM, 100 GB disk.
- Kubernetes: k3d running K3s.
- CI: GitHub Actions.
- Image registry: GitHub Container Registry, `ghcr.io`.
- API runtime: Spring Boot 3.5 on Java 17.
- GitOps: Argo CD.
- Progressive delivery: Argo Rollouts.
- Gateway: APISIX.
- Observability: Prometheus, Grafana, Loki, SkyWalking.

## Workload Tracks

- `blog-api` + `blog-web` remain the smallest possible workloads for Helm,
  APISIX, Argo CD, and Argo Rollouts drills on k3d.
- `admin-server`, `api-gateway`, `user-service`, and `order-service` provide a
  local-first Java service stack for CI, preview deploy, self-hosted runner CD,
  request tracing, and smoke-check exercises.

The blog API exposes a version string through `APP_VERSION`, which keeps
canary, rollback, metrics, and Java agent tracing behavior easy to observe.

## How This Lab Should Be Used

1. Push app code to GitHub.
2. GitHub Actions runs root Maven verification and builds container images.
3. Pull requests can spin up a local preview stack through SSH to the Mac host.
4. Mainline builds publish images to GHCR.
5. Argo CD syncs the k3d workloads from the deployment path.
6. Argo Rollouts performs canary steps.
7. APISIX applies routing and rate limiting.
8. Grafana/Prometheus/Loki/SkyWalking show deployment behavior.

Keep secrets outside Git. Use GitHub Actions secrets, Kubernetes Secrets, or a
cloud secret manager.

## Local Access

All main UIs can be reached through APISIX on port `8080`:

```text
http://blog.localhost:8080/
http://argocd.localhost:8080/
http://grafana.localhost:8080/login
http://prometheus.localhost:8080/graph
http://skywalking.localhost:8080/
http://loki.localhost:8080/ready
```

Grafana ships with two lab-specific dashboards:

```text
Enterprise Delivery Lab Overview
Enterprise Delivery Lab High Frequency
```

For local setup, start with [docs/local-runbook.md](docs/local-runbook.md).
