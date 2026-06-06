#!/usr/bin/env bash
set -euo pipefail

helm upgrade --install apisix /Users/mac/pspace/ws03/deploy/helm/traffic-gateway/charts/apisix-2.11.2.tgz \
  -n apisix \
  --create-namespace \
  -f infra/local-k3d/apisix-values.yaml \
  --wait \
  --timeout 10m

kubectl get pods -n apisix
kubectl get svc -n apisix
