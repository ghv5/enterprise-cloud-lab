#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-enterprise-lab}"

k3d cluster delete "${CLUSTER_NAME}"
