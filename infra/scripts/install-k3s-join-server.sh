#!/usr/bin/env bash
set -euo pipefail

: "${K3S_TOKEN:?set K3S_TOKEN before running}"
: "${FIRST_SERVER_URL:?set FIRST_SERVER_URL, for example https://10.0.0.10:6443}"
: "${PUBLIC_IP:?set PUBLIC_IP before running}"

curl -sfL https://get.k3s.io | sh -s - server \
  --server "${FIRST_SERVER_URL}" \
  --token "${K3S_TOKEN}" \
  --tls-san "${PUBLIC_IP}" \
  --write-kubeconfig-mode 600 \
  --disable traefik
