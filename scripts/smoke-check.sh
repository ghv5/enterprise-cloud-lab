#!/bin/zsh
set -euo pipefail

BASE_URL="${1:-http://localhost:18080}"

curl -fsS "${BASE_URL}/actuator/health" >/dev/null
curl -fsS "${BASE_URL}/api/v1/users/1" >/dev/null
curl -fsS "${BASE_URL}/api/v1/orders/1" >/dev/null

echo "Smoke check passed for ${BASE_URL}"
