#!/bin/zsh
set -euo pipefail

ENV_NAME="${1:-dev}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/ops/environments/${ENV_NAME}.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing environment file: ${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

mkdir -p "${ROOT_DIR}/.local/run/${ENV_NAME}"
cd "${ROOT_DIR}"

if docker info >/dev/null 2>&1; then
  docker compose -f "${ROOT_DIR}/ops/docker/docker-compose.observability.yml" up -d
elif [[ "${SKIP_OBSERVABILITY_DOCKER:-false}" == "true" ]]; then
  echo "Docker daemon is not running, skip observability stack because SKIP_OBSERVABILITY_DOCKER=true"
else
  echo "Docker daemon is not running. Start Docker Desktop or run with SKIP_OBSERVABILITY_DOCKER=true" >&2
  exit 1
fi

nohup "${ROOT_DIR}/mvnw" -pl apps/admin-server -am spring-boot:run \
  -Dspring-boot.run.arguments="--server.port=${ADMIN_SERVER_PORT}" \
  > "${ROOT_DIR}/.local/run/${ENV_NAME}/admin-server.log" 2>&1 &
echo $! > "${ROOT_DIR}/.local/run/${ENV_NAME}/admin-server.pid"

nohup "${ROOT_DIR}/mvnw" -pl apps/user-service -am spring-boot:run \
  -Dspring-boot.run.arguments="--server.port=${USER_SERVICE_PORT} --spring.boot.admin.client.url=${SPRING_BOOT_ADMIN_URL}" \
  > "${ROOT_DIR}/.local/run/${ENV_NAME}/user-service.log" 2>&1 &
echo $! > "${ROOT_DIR}/.local/run/${ENV_NAME}/user-service.pid"

nohup "${ROOT_DIR}/mvnw" -pl apps/order-service -am spring-boot:run \
  -Dspring-boot.run.arguments="--server.port=${ORDER_SERVICE_PORT} --spring.boot.admin.client.url=${SPRING_BOOT_ADMIN_URL}" \
  > "${ROOT_DIR}/.local/run/${ENV_NAME}/order-service.log" 2>&1 &
echo $! > "${ROOT_DIR}/.local/run/${ENV_NAME}/order-service.pid"

nohup "${ROOT_DIR}/mvnw" -pl apps/api-gateway -am spring-boot:run \
  -Dspring-boot.run.arguments="--server.port=${GATEWAY_PORT} --spring.boot.admin.client.url=${SPRING_BOOT_ADMIN_URL} --user.service.url=${USER_SERVICE_URL} --order.service.url=${ORDER_SERVICE_URL}" \
  > "${ROOT_DIR}/.local/run/${ENV_NAME}/api-gateway.log" 2>&1 &
echo $! > "${ROOT_DIR}/.local/run/${ENV_NAME}/api-gateway.pid"

echo "Environment ${ENV_NAME} started."
