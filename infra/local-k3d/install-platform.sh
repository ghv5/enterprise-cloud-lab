#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install argo-cd infra/local-k3d/charts/argo-cd-8.3.0.tgz \
  -n argocd \
  -f infra/local-k3d/argo-cd-values.local.yaml \
  --wait \
  --timeout 10m

kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install argo-rollouts infra/local-k3d/charts/argo-rollouts-2.40.4.tgz \
  -n argo-rollouts \
  --wait \
  --timeout 10m

echo "Waiting for Argo CD..."
kubectl rollout status deployment/argo-cd-argocd-server -n argocd --timeout=300s

echo "Argo CD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo

echo "Next: install APISIX and observability, then apply deploy/argocd/blog-lab-apps.yaml."
