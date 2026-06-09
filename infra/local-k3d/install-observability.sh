#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kube-prometheus-stack deploy/helm/observability/charts/kube-prometheus-stack-86.1.1.tgz \
  -n observability \
  -f deploy/helm/observability/kube-prometheus-stack.values.local.yaml \
  --wait \
  --timeout 15m

helm upgrade --install loki deploy/helm/observability/charts/loki-7.0.0.tgz \
  -n observability \
  -f deploy/helm/observability/loki.values.local.yaml \
  --wait \
  --timeout 15m

helm upgrade --install alloy deploy/helm/observability/charts/alloy-1.8.2.tgz \
  -n observability \
  -f deploy/helm/observability/alloy.values.local.yaml \
  --wait \
  --timeout 15m

helm upgrade --install observability-addons deploy/helm/observability-addons \
  -n observability \
  -f deploy/helm/observability-addons/values-local.yaml \
  --wait \
  --timeout 10m

helm upgrade --install blog-api deploy/helm/blog-api \
  -n demo \
  --reuse-values \
  -f deploy/helm/blog-api/values-local-observability.yaml \
  --wait \
  --timeout 10m

kubectl get pods -n observability
kubectl get servicemonitor -A
