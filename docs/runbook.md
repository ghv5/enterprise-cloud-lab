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
kubectl argo rollouts get rollout blog-api-blog-api -n demo --watch
```

Promote or abort:

```bash
kubectl argo rollouts promote blog-api-blog-api -n demo
kubectl argo rollouts abort blog-api-blog-api -n demo
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

Expect `429` after the configured threshold.
