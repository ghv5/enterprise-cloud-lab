# Enterprise Cloud Lab

This repository is a lightweight enterprise deployment lab for a local Mac
workstation first, with cloud servers kept as an optional later target. The
business apps are intentionally small; the main focus is CI/CD, GitOps
deployment, rollback, rate limiting, canary release, and observability.

## Directory Layout

```text
apps/
  blog-api/              # Minimal Spring Boot API used for rollout and metrics demos
  blog-web/              # Static blog frontend served by Nginx
ci/
  github-actions/        # GitHub Actions workflow templates for GHCR
deploy/
  argocd/                # Argo CD Application manifests
  helm/                  # Helm charts for the sample apps
  apisix/                # APISIX route and rate-limit examples
infra/
  local-k3d/             # Local Mac cluster scripts
  k3s/                   # Optional three-node cloud K3s planning notes
  scripts/               # Optional cloud install command templates
docs/
  architecture.md        # Target architecture and sizing
  local-runbook.md       # Local Mac workflow
  runbook.md             # Deployment, canary, rollback, and verification flow
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

## Business Apps

- `blog-api`: small Spring Boot HTTP service with `/actuator/health`,
  `/actuator/prometheus`, `/api/info`, and `/api/posts`.
- `blog-web`: static page that calls the API through the gateway.

The API exposes a version string through `APP_VERSION`, which makes canary,
rollback, metrics, and Java agent tracing behavior easy to observe.

## How This Lab Should Be Used

1. Push app code to GitHub.
2. GitHub Actions builds images and pushes them to GHCR.
3. CI updates image tags in the deployment Git path.
4. Argo CD syncs the desired state to K3s.
5. Argo Rollouts performs canary steps.
6. APISIX applies routing and rate limiting.
7. Grafana/Prometheus/Loki show deployment behavior.

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
