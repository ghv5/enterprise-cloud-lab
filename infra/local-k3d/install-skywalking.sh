#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-enterprise-lab}"

import_image() {
  local image="$1"
  if ! k3d image import "${image}" -c "${CLUSTER_NAME}"; then
    echo "warning: failed to import ${image} into k3d; falling back to direct pull from registry at runtime" >&2
  fi
}

docker pull apache/skywalking-java-agent:9.3.0-java17 >/dev/null
docker pull docker.m.daocloud.io/apache/skywalking-oap-server:9.7.0 >/dev/null
docker pull docker.m.daocloud.io/apache/skywalking-ui:9.7.0 >/dev/null

import_image apache/skywalking-java-agent:9.3.0-java17
import_image docker.m.daocloud.io/apache/skywalking-oap-server:9.7.0
import_image docker.m.daocloud.io/apache/skywalking-ui:9.7.0

kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install skywalking deploy/helm/observability-tracing \
  -n observability \
  -f deploy/helm/observability-tracing/values-local.yaml \
  --wait \
  --timeout 15m

helm upgrade --install blog-api deploy/helm/blog-api \
  -n demo \
  --reuse-values \
  -f deploy/helm/blog-api/values-local-skywalking.yaml \
  --wait \
  --timeout 10m

kubectl get pods -n observability
kubectl get rollout -n demo
