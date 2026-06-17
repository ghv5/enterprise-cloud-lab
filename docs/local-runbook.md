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
./mvnw -v
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

Copy the workflow templates into GitHub's workflow directory:

```bash
mkdir -p .github/workflows
cp ci/github-actions/*.yml .github/workflows/
```

Push the workflows to trigger CI, image builds, preview deploys, and optional
local self-hosted runner CD.

### Optional: run the local reference services first

This stack does not need k3d. It is useful for validating the merged
`apps/ + platform/ + ops/ + scripts/` flow before touching the cluster path.

```bash
make verify
make dev-up
make smoke
```

Access entries:

```text
http://localhost:18080          # api-gateway
http://localhost:19090          # Spring Boot Admin
http://localhost:19091          # Prometheus
http://localhost:19092          # Grafana
http://localhost:19093          # Alertmanager
```

Stop it with:

```bash
make dev-down
```

## 8. Local App Smoke Test

When Docker Hub is slow, build the API jar locally first and use the local
Dockerfile:

```bash
cd apps/blog-api
../../mvnw -B -DskipTests package
cd ../..
docker build -f apps/blog-api/Dockerfile.local -t blog-api:local apps/blog-api
docker build -t blog-web:local apps/blog-web
k3d image import blog-api:local blog-web:local -c enterprise-lab
infra/local-k3d/deploy-local-apps.sh
curl http://blog.localhost:8080/api/posts
```

The demo APISIX limit is intentionally low: 5 requests per 60 seconds. This
makes manual verification fast.

Manual check:

```bash
for i in $(seq 1 12); do
  curl -s -o /dev/null -w "%{http_code}\n" http://blog.localhost:8080/api/posts
done
```

You should see `429` after the quota is exhausted.

## 9. Deploy Apps Through Argo CD

After APISIX is installed, apply the Argo CD applications:

```bash
kubectl apply -f deploy/argocd/blog-lab-apps.yaml
```

The blog app images are configured as:

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

## 10. Install Observability

Install Prometheus, Grafana, Loki, Alloy, and the APISIX `ServiceMonitor`:

```bash
infra/local-k3d/install-observability.sh
```

This step also upgrades `blog-api` once so that Prometheus can scrape
`/actuator/prometheus`.

Main access entries through APISIX:

```text
http://blog.localhost:8080/
http://argocd.localhost:8080/
http://grafana.localhost:8080/login
http://prometheus.localhost:8080/graph
http://skywalking.localhost:8080/
http://loki.localhost:8080/ready
```

Grafana credentials:

```bash
kubectl -n observability get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-user}' | base64 -d; echo

kubectl -n observability get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Grafana dashboard names:

```text
Enterprise Delivery Lab Overview
Enterprise Delivery Lab High Frequency
```

Optional troubleshooting access:

```bash
infra/local-k3d/port-forward-prometheus.sh
kubectl port-forward -n observability svc/loki 3100:3100
infra/local-k3d/port-forward-grafana.sh
infra/local-k3d/port-forward-skywalking.sh
```

## 11. Install SkyWalking

```bash
infra/local-k3d/install-skywalking.sh
```

This installer:

- deploys SkyWalking OAP and UI
- imports the Java agent image if possible
- upgrades `blog-api` with `JAVA_TOOL_OPTIONS=-javaagent:...`

Open the UI locally:

```bash
open http://skywalking.localhost:8080/
```

## 12. Manual Acceptance Test

### 12.1 Business and gateway

```bash
curl http://blog.localhost:8080/api/posts
curl http://blog.localhost:8080/api/info
```

Expected:

- HTTP `200`
- `meta.version` is `local`

### 12.2 Rate limit

Wait for a fresh 60-second window, then run:

```bash
for i in $(seq 1 40); do
  curl -s -o /dev/null -w "%{http_code}\n" http://blog.localhost:8080/api/posts
done
```

Expected:

- you should see `429` within the 40 requests

### 12.3 Rollout restart

```bash
kubectl patch rollout blog-api-blog-api -n demo --type merge \
  -p "{\"spec\":{\"restartAt\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}"

kubectl get rollout blog-api-blog-api -n demo -w
```

Expected:

- new ReplicaSet appears
- rollout pauses on canary step and then resumes after the configured pause

### 12.4 Prometheus

```bash
curl -s http://prometheus.localhost:8080/api/v1/targets | jq '.data.activeTargets[] |
  {job: .labels.job, health: .health, scrapeUrl: .scrapeUrl} |
  select((.job|test("blog-api|apisix-prometheus-metrics|alloy")) or (.scrapeUrl|test("blog-api|apisix")))'
```

Expected:

- `blog-api-blog-api` targets are `up`
- `apisix-prometheus-metrics` target is `up`
- `alloy` targets are `up`

Useful metric checks:

```bash
curl -s 'http://prometheus.localhost:8080/api/v1/query?query=http_server_requests_seconds_count%7Bapplication%3D%22blog-api%22%2Curi%3D%22%2Fapi%2Fposts%22%7D' | jq
curl -s 'http://prometheus.localhost:8080/api/v1/query?query=histogram_quantile(0.95,sum%20by%20(le)(rate(http_server_requests_seconds_bucket%7Bapplication%3D%22blog-api%22,uri%3D%22%2Fapi%2Fposts%22%7D%5B15m%5D)))' | jq
curl -s 'http://prometheus.localhost:8080/api/v1/query?query=sum(rate(apisix_http_requests_total%5B2m%5D))' | jq
```

### 12.5 Loki

```bash
curl -s 'http://loki.localhost:8080/loki/api/v1/query_range?query=%7Bnamespace%3D%22demo%22,app%3D%22blog-api%22%7D&limit=5' | jq
```

Expected:

- at least one stream for `namespace=demo`
- labels include `app=blog-api`, `pod`, `container`

### 12.6 Grafana datasource wiring

```bash
USER=$(kubectl -n observability get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-user}' | base64 -d)
PASS=$(kubectl -n observability get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d)
curl -s -u "$USER:$PASS" http://grafana.localhost:8080/api/datasources | jq
curl -s -u "$USER:$PASS" 'http://grafana.localhost:8080/api/search?query=Enterprise' | jq
```

Expected:

- datasource list contains `Prometheus`
- datasource list contains `Loki`
- dashboard list contains `Enterprise Delivery Lab Overview`
- dashboard list contains `Enterprise Delivery Lab High Frequency`

### 12.7 SkyWalking

Generate traffic first:

```bash
for i in $(seq 1 20); do
  curl -s http://blog.localhost:8080/api/posts >/dev/null
done
```

Then query services:

```bash
START=$(date '+%Y-%m-%d %H00')
END=$(date '+%Y-%m-%d %H59')
curl -s http://skywalking.localhost:8080/graphql \
  -H 'Content-Type: application/json' \
  -d "{\"query\":\"query { getAllServices(duration: {start: \\\"${START}\\\", end: \\\"${END}\\\", step: MINUTE}) { id name shortName layers normal } }\"}" | jq
```

Expected:

- service list contains `blog-api|demo|`

Query traces:

```bash
SERVICE_ID=$(curl -s http://skywalking.localhost:8080/graphql \
  -H 'Content-Type: application/json' \
  -d "{\"query\":\"query { getAllServices(duration: {start: \\\"${START}\\\", end: \\\"${END}\\\", step: MINUTE}) { id name } }\"}" \
  | jq -r '.data.getAllServices[] | select(.name=="blog-api|demo|") | .id')

curl -s http://skywalking.localhost:8080/graphql \
  -H 'Content-Type: application/json' \
  -d "{\"query\":\"query { queryBasicTraces(condition: { serviceId: \\\"${SERVICE_ID}\\\", queryDuration: {start: \\\"${START}\\\", end: \\\"${END}\\\", step: MINUTE}, traceState: ALL, queryOrder: BY_START_TIME, paging: { pageNum: 1, pageSize: 100 } }) { traces { endpointNames duration isError traceIds } } }\"}" | jq
```

Expected:

- traces include `GET:/api/posts`
- `isError` is `false`

### 12.8 Automated self-test

Run:

```bash
infra/local-k3d/self-test.sh
```

Expected:

- script exits with code `0`
- final line is `self-test passed`

## 13. Verified Snapshot

```text
Verified locally on 2026-06-06:
- APISIX rate limit returned 429 after quota exhaustion
- Prometheus scraped blog-api, APISIX, and Alloy
- http_server_requests_seconds_count{uri="/api/posts"} returned samples for two blog-api instances
- Loki returned demo/blog-api log streams
- Grafana datasource API contained Prometheus and Loki
- SkyWalking service list contained blog-api|demo|
- SkyWalking traces contained GET:/api/posts
```
