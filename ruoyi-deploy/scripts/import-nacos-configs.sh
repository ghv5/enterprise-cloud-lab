#!/usr/bin/env bash

set -euo pipefail

KUBECTL_BIN="${KUBECTL_BIN:-/Applications/Docker.app/Contents/Resources/bin/kubectl}"
MYSQL_NAMESPACE="${MYSQL_NAMESPACE:-infra}"
MYSQL_DEPLOYMENT="${MYSQL_DEPLOYMENT:-release-platform-infra-mysql}"
MYSQL_USER="${MYSQL_USER:-ruoyi}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-ruoyi123}"
NACOS_NAMESPACE="${NACOS_NAMESPACE:-infra}"
NACOS_SERVICE="${NACOS_SERVICE:-release-platform-infra-nacos}"
NACOS_PORT="${NACOS_PORT:-8848}"
NACOS_USERNAME="${NACOS_USERNAME:-nacos}"
NACOS_PASSWORD="${NACOS_PASSWORD:-nacos}"
NACOS_TENANT="${NACOS_TENANT:-dev}"
NACOS_GROUP="${NACOS_GROUP:-DEFAULT_GROUP}"
LOCAL_PORT="${LOCAL_PORT:-18848}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${REPO_ROOT}/RuoYi-Cloud-Plus/script/config/nacos"
WORK_DIR="$(mktemp -d)"
PORT_FORWARD_PID=""
ACCESS_TOKEN=""

cleanup() {
  if [[ -n "${PORT_FORWARD_PID}" ]]; then
    kill "${PORT_FORWARD_PID}" >/dev/null 2>&1 || true
    wait "${PORT_FORWARD_PID}" 2>/dev/null || true
  fi
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "missing config file: ${path}" >&2
    exit 1
  fi
}

seed_nacos_metadata() {
  printf '%s\n' \
    "INSERT IGNORE INTO tenant_info(id, kp, tenant_id, tenant_name, tenant_desc, create_source, gmt_create, gmt_modified) VALUES (1, '1', 'dev', 'dev', '开发环境', NULL, 1641741261189, 1641741261189);" \
    "INSERT IGNORE INTO tenant_info(id, kp, tenant_id, tenant_name, tenant_desc, create_source, gmt_create, gmt_modified) VALUES (2, '1', 'prod', 'prod', '生产环境', NULL, 1641741270448, 1641741287236);" \
    "INSERT IGNORE INTO users(username, password, enabled) VALUES ('nacos', '\$2a\$10\$EuWPZHzz32dJN7jexM34MOeYirDdFAZm2kuWj7VEOJhhZkDrxfvUu', TRUE);" \
    "INSERT IGNORE INTO roles(username, role) VALUES ('nacos', 'ROLE_ADMIN');" | \
    "${KUBECTL_BIN}" exec -i -n "${MYSQL_NAMESPACE}" "deployment/${MYSQL_DEPLOYMENT}" -- \
      sh -lc "mysql --default-character-set=utf8mb4 -u${MYSQL_USER} -p${MYSQL_PASSWORD} ry-config" >/dev/null
}

render_file() {
  local src="$1"
  local dest="$2"
  sed \
    -e 's|jdbc:mysql://localhost:3306/ry-cloud|jdbc:mysql://release-platform-infra-mysql.infra.svc.cluster.local:3306/ry-cloud|g' \
    -e 's|jdbc:mysql://localhost:3306/ry-job|jdbc:mysql://release-platform-infra-mysql.infra.svc.cluster.local:3306/ry-job|g' \
    -e 's|jdbc:mysql://localhost:3306/ry-workflow|jdbc:mysql://release-platform-infra-mysql.infra.svc.cluster.local:3306/ry-workflow|g' \
    -e 's|username: root|username: ruoyi|g' \
    -e 's|password: password|password: ruoyi123|g' \
    -e 's|host: localhost|host: release-platform-infra-redis.infra.svc.cluster.local|g' \
    -e 's|address: http://localhost:80|address: http://localhost:9080|g' \
    "${src}" > "${dest}"
}

publish_config() {
  local file_name="$1"
  local file_path="$2"
  local config_type="${3:-yaml}"

  curl -sfS -X POST "http://127.0.0.1:${LOCAL_PORT}/nacos/v1/cs/configs?accessToken=${ACCESS_TOKEN}" \
    --data-urlencode "tenant=${NACOS_TENANT}" \
    --data-urlencode "group=${NACOS_GROUP}" \
    --data-urlencode "dataId=${file_name}" \
    --data-urlencode "type=${config_type}" \
    --data-urlencode "content@${file_path}" >/dev/null

  echo "[nacos] published ${file_name}"
}

for file in \
  application-common.yml \
  datasource.yml \
  ruoyi-gateway.yml \
  ruoyi-auth.yml \
  ruoyi-system.yml \
  ruoyi-resource.yml \
  ruoyi-monitor.yml
do
  require_file "${CONFIG_DIR}/${file}"
done

seed_nacos_metadata

"${KUBECTL_BIN}" port-forward -n "${NACOS_NAMESPACE}" "svc/${NACOS_SERVICE}" "${LOCAL_PORT}:${NACOS_PORT}" \
  >/tmp/ruoyi-nacos-port-forward.log 2>&1 &
PORT_FORWARD_PID=$!
sleep 5

ACCESS_TOKEN="$(
  curl -sfS -X POST "http://127.0.0.1:${LOCAL_PORT}/nacos/v1/auth/users/login" \
    -d "username=${NACOS_USERNAME}&password=${NACOS_PASSWORD}" |
    sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p'
)"

if [[ -z "${ACCESS_TOKEN}" ]]; then
  echo "failed to obtain nacos access token" >&2
  exit 1
fi

render_file "${CONFIG_DIR}/application-common.yml" "${WORK_DIR}/application-common.yml"
render_file "${CONFIG_DIR}/datasource.yml" "${WORK_DIR}/datasource.yml"
cp "${CONFIG_DIR}/ruoyi-gateway.yml" "${WORK_DIR}/ruoyi-gateway.yml"
render_file "${CONFIG_DIR}/ruoyi-auth.yml" "${WORK_DIR}/ruoyi-auth.yml"
cp "${CONFIG_DIR}/ruoyi-system.yml" "${WORK_DIR}/ruoyi-system.yml"
cp "${CONFIG_DIR}/ruoyi-resource.yml" "${WORK_DIR}/ruoyi-resource.yml"
cp "${CONFIG_DIR}/ruoyi-monitor.yml" "${WORK_DIR}/ruoyi-monitor.yml"

publish_config "application-common.yml" "${WORK_DIR}/application-common.yml"
publish_config "datasource.yml" "${WORK_DIR}/datasource.yml"
publish_config "ruoyi-gateway.yml" "${WORK_DIR}/ruoyi-gateway.yml"
publish_config "ruoyi-auth.yml" "${WORK_DIR}/ruoyi-auth.yml"
publish_config "ruoyi-system.yml" "${WORK_DIR}/ruoyi-system.yml"
publish_config "ruoyi-resource.yml" "${WORK_DIR}/ruoyi-resource.yml"
publish_config "ruoyi-monitor.yml" "${WORK_DIR}/ruoyi-monitor.yml"

echo "[nacos] complete"
