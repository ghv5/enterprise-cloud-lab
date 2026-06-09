#!/usr/bin/env bash
set -euo pipefail

kubectl port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090
