# Runbook

## Local API Test

Requires Java 17 and Maven.

```bash
cd apps/blog-api
mvn test
PORT=8080 APP_VERSION=local mvn spring-boot:run
```

## Build Images Locally

```bash
docker build -t blog-api:local apps/blog-api
docker build -t blog-web:local apps/blog-web
```

## GitHub Actions

The workflow template is stored at:

```text
ci/github-actions/build-and-push.yml
```

For GitHub to execute it, place it at repository root:

```text
.github/workflows/build-and-push.yml
```

The workflow pushes images to:

```text
ghcr.io/<github-owner>/blog-api:<git-sha>
ghcr.io/<github-owner>/blog-web:<git-sha>
```

## GHCR Pull Secret

For private GHCR images, create a pull secret in the target namespace:

```bash
kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-pat-with-read-packages> \
  --docker-email=<email> \
  -n demo
```

Then set this in Helm values:

```yaml
imagePullSecrets:
  - name: ghcr-pull-secret
```

## Argo CD Apps

Before applying, replace placeholders in:

```text
deploy/argocd/blog-lab-apps.yaml
deploy/helm/blog-api/values.yaml
deploy/helm/blog-web/values.yaml
```

Apply:

```bash
kubectl apply -f deploy/argocd/blog-lab-apps.yaml
```

The same file also defines `blog-gateway`, which lets Argo CD manage the APISIX
route manifests under `deploy/apisix`.

## Canary Drill

Update the API image tag and `APP_VERSION`, then let Argo CD sync:

```yaml
image:
  tag: <new-git-sha>

env:
  APP_VERSION: <new-git-sha>
```

Watch rollout:

```bash
kubectl get rollout blog-api-blog-api -n demo
```

Restart the Argo Rollout without the kubectl plugin:

```bash
kubectl patch rollout blog-api-blog-api -n demo --type merge \
  -p "{\"spec\":{\"restartAt\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}"
```

If you install the Argo Rollouts kubectl plugin, you can also promote or abort:

```bash
kubectl argo rollouts promote blog-api-blog-api -n demo
kubectl argo rollouts abort blog-api-blog-api -n demo
```

Without the plugin, the rollout still advances through timed pause steps. Watch
it with:

```bash
kubectl describe rollout blog-api-blog-api -n demo
kubectl get pods -n demo -w
```

## Rate-Limit Drill

If you do not want Argo CD to manage the route yet, apply APISIX route and
plugin config manually after APISIX is installed:

```bash
kubectl apply -f deploy/apisix/blog-routes.yaml
```

Generate traffic:

```bash
for i in $(seq 1 150); do curl -s -o /dev/null -w "%{http_code}\n" http://<gateway>/api/posts; done
```

The local demo threshold is intentionally low, so expect `429` after a few
requests.

## Observability Drill

Install the local observability stack:

```bash
infra/local-k3d/install-observability.sh
infra/local-k3d/install-skywalking.sh
```

Prometheus checks:

```bash
curl -s http://prometheus.localhost:8080/api/v1/targets | jq
curl -s 'http://prometheus.localhost:8080/api/v1/query?query=http_server_requests_seconds_count%7Bapplication%3D%22blog-api%22%2Curi%3D%22%2Fapi%2Fposts%22%7D' | jq
curl -s 'http://prometheus.localhost:8080/api/v1/query?query=histogram_quantile(0.95,sum%20by%20(le)(rate(http_server_requests_seconds_bucket%7Bapplication%3D%22blog-api%22,uri%3D%22%2Fapi%2Fposts%22%7D%5B15m%5D)))' | jq
curl -s 'http://prometheus.localhost:8080/api/v1/query?query=sum(rate(apisix_http_requests_total%5B2m%5D))' | jq
```

Loki check:

```bash
curl -s 'http://loki.localhost:8080/loki/api/v1/query_range?query=%7Bnamespace%3D%22demo%22,app%3D%22blog-api%22%7D&limit=5' | jq
```

SkyWalking check:

```bash
START=$(date '+%Y-%m-%d %H00')
END=$(date '+%Y-%m-%d %H59')
curl -s http://skywalking.localhost:8080/graphql \
  -H 'Content-Type: application/json' \
  -d "{\"query\":\"query { getAllServices(duration: {start: \\\"${START}\\\", end: \\\"${END}\\\", step: MINUTE}) { id name shortName } }\"}" | jq
```

The local verification target is:

```text
Prometheus target up
Loki demo/blog-api stream visible
SkyWalking service blog-api|demo| visible
SkyWalking GET:/api/posts trace visible
Grafana dashboards:
- Enterprise Delivery Lab Overview
- Enterprise Delivery Lab High Frequency
```
