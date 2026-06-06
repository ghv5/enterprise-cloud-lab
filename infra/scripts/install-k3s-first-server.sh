#!/usr/bin/env bash
set -euo pipefail

: "${K3S_TOKEN:?set K3S_TOKEN before running}"
: "${PUBLIC_IP:?set PUBLIC_IP before running}"

curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --token "${K3S_TOKEN}" \
  --tls-san "${PUBLIC_IP}" \
  --write-kubeconfig-mode 600 \
  --disable traefik
