#!/usr/bin/env bash
set -euo pipefail

kubectl port-forward -n observability svc/skywalking-ui 18080:18080
