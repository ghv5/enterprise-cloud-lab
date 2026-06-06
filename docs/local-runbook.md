# Local Mac Runbook

This runbook assumes this directory is the repository root for:

```text
https://github.com/ghv5/enterprise-cloud-lab.git
```

## 1. Prepare Docker Desktop

Recommended Docker Desktop settings for a 32 GB Mac:

```text
CPU: 8
Memory: 18-22 GB
Disk: 100 GB+
```

## 2. Required Tools

```bash
docker version
k3d version
kubectl version --client
helm version
gh auth status
```

Install missing tools with Homebrew if needed:

```bash
brew install k3d kubectl helm gh argocd argo-rollouts
```

## 3. Create Local Cluster

```bash
infra/local-k3d/create-cluster.sh
```

Default local ports:

```text
8080  HTTP gateway
8443  HTTPS gateway
6550  Kubernetes API
```

## 4. Install Platform Controllers

```bash
infra/local-k3d/install-platform.sh
```

The installer uses local chart packages under `infra/local-k3d/charts/` because
`raw.githubusercontent.com` may be unavailable on this network.

Open Argo CD locally:

```bash
infra/local-k3d/port-forward-argocd.sh
```

Then visit:

```text
https://127.0.0.1:8081
```

Username:

```text
admin
```

## 5. Push Repository to GitHub

## 5. Install APISIX

```bash
infra/local-k3d/install-apisix.sh
```

After it is ready, the local gateway should be reachable through:

```text
http://127.0.0.1:8080
```

## 6. Push Repository to GitHub

From this directory:

```bash
git init
git branch -M main
git remote add origin https://github.com/ghv5/enterprise-cloud-lab.git
git add .
git commit -m "feat: initialize enterprise cloud lab"
git push -u origin main
```

If the remote repository already has commits, fetch and merge first.

## 7. Enable GitHub Actions

Copy the workflow template into GitHub's workflow directory:

```bash
mkdir -p .github/workflows
cp ci/github-actions/build-and-push.yml .github/workflows/build-and-push.yml
```

Push the workflow to trigger GHCR image builds.

## 8. Local App Smoke Test

When Docker Hub is slow, build the API jar locally first and use the local
Dockerfile:

```bash
cd apps/blog-api
mvn -B -DskipTests package
cd ../..
docker build -f apps/blog-api/Dockerfile.local -t blog-api:local apps/blog-api
docker build -t blog-web:local apps/blog-web
k3d image import blog-api:local blog-web:local -c enterprise-lab
infra/local-k3d/deploy-local-apps.sh
curl http://127.0.0.1:8080/api/posts
```

The demo APISIX limit is intentionally low: 5 requests per 60 seconds. This
makes manual verification fast.

Manual check:

```bash
for i in $(seq 1 12); do
  curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/api/posts
done
```

You should see `429` after the quota is exhausted.

## 9. Deploy Apps Through Argo CD

After APISIX is installed, apply the Argo CD applications:

```bash
kubectl apply -f deploy/argocd/blog-lab-apps.yaml
```

The app images are configured as:

```text
ghcr.io/ghv5/blog-api:latest
ghcr.io/ghv5/blog-web:latest
```

For private GHCR images, create `ghcr-pull-secret` in namespace `demo` and set
`imagePullSecrets` in Helm values.

To manually restart the Argo Rollout without the kubectl plugin:

```bash
kubectl patch rollout blog-api-blog-api -n demo --type merge \
  -p "{\"spec\":{\"restartAt\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}"
```

Do not use `kubectl rollout restart rollout ...`; Kubernetes' built-in rollout
command does not handle Argo Rollouts CRDs.

## 10. Observability

First milestone:

```text
Spring Boot Actuator: /actuator/health and /actuator/prometheus
APISIX metrics
Grafana dashboards
Loki logs
```

SkyWalking can be added later after the first GitOps flow is stable.
