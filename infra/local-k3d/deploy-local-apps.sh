#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install blog-api deploy/helm/blog-api \
  -n demo \
  --set image.repository=blog-api \
  --set image.tag=local \
  --set image.pullPolicy=IfNotPresent \
  --set env.APP_VERSION=local \
  --wait \
  --timeout 5m

helm upgrade --install blog-web deploy/helm/blog-web \
  -n demo \
  --set image.repository=blog-web \
  --set image.tag=local \
  --set image.pullPolicy=IfNotPresent \
  --wait \
  --timeout 5m

kubectl apply -f deploy/apisix/

kubectl get pods -n demo
