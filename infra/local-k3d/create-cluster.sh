#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-enterprise-lab}"
API_PORT="${API_PORT:-6550}"
HTTP_PORT="${HTTP_PORT:-8080}"
HTTPS_PORT="${HTTPS_PORT:-8443}"

k3d cluster create "${CLUSTER_NAME}" \
  --servers 1 \
  --agents 2 \
  --api-port "127.0.0.1:${API_PORT}" \
  --port "127.0.0.1:${HTTP_PORT}:80@loadbalancer" \
  --port "127.0.0.1:${HTTPS_PORT}:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:*" \
  --wait

kubectl config use-context "k3d-${CLUSTER_NAME}"
kubectl get nodes
