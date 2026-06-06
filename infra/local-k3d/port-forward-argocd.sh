#!/usr/bin/env bash
set -euo pipefail

LOCAL_PORT="${LOCAL_PORT:-8081}"

kubectl port-forward -n argocd svc/argo-cd-argocd-server "${LOCAL_PORT}:443"
