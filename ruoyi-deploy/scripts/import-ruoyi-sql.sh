#!/usr/bin/env bash

set -euo pipefail

KUBECTL_BIN="${KUBECTL_BIN:-/Applications/Docker.app/Contents/Resources/bin/kubectl}"
MYSQL_NAMESPACE="${MYSQL_NAMESPACE:-infra}"
MYSQL_DEPLOYMENT="${MYSQL_DEPLOYMENT:-release-platform-infra-mysql}"
MYSQL_USER="${MYSQL_USER:-ruoyi}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-ruoyi123}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SQL_DIR="${REPO_ROOT}/RuoYi-Cloud-Plus/script/sql"

if ! command -v "${KUBECTL_BIN}" >/dev/null 2>&1; then
  echo "kubectl binary not found: ${KUBECTL_BIN}" >&2
  exit 1
fi

if [[ ! -d "${SQL_DIR}" ]]; then
  echo "sql directory not found: ${SQL_DIR}" >&2
  exit 1
fi

SQL_ENTRIES=(
  "ry-cloud:ry-cloud.sql"
  "ry-config:ry-config.sql"
  "ry-job:ry-job.sql"
  "ry-workflow:ry-workflow.sql"
)

mysql_exec() {
  "${KUBECTL_BIN}" exec -i -n "${MYSQL_NAMESPACE}" "deployment/${MYSQL_DEPLOYMENT}" -- \
    sh -lc "mysql --default-character-set=utf8mb4 -N -B -u${MYSQL_USER} -p${MYSQL_PASSWORD} $*"
}

table_count() {
  local database="$1"
  mysql_exec "-e \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${database}'\""
}

import_sql() {
  local database="$1"
  local sql_file="$2"
  echo "[sql] importing ${database} from ${sql_file}"
  "${KUBECTL_BIN}" exec -i -n "${MYSQL_NAMESPACE}" "deployment/${MYSQL_DEPLOYMENT}" -- \
    sh -lc "mysql --default-character-set=utf8mb4 -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${database}" < "${sql_file}"
}

for entry in "${SQL_ENTRIES[@]}"; do
  database="${entry%%:*}"
  sql_file="${SQL_DIR}/${entry#*:}"
  if [[ ! -f "${sql_file}" ]]; then
    echo "missing sql file: ${sql_file}" >&2
    exit 1
  fi

  current_count="$(table_count "${database}" | tr -d '\r')"
  if [[ "${current_count}" != "0" ]]; then
    echo "[sql] skip ${database}, existing tables=${current_count}"
    continue
  fi

  import_sql "${database}" "${sql_file}"
  new_count="$(table_count "${database}" | tr -d '\r')"
  echo "[sql] ${database} tables=${new_count}"
done

echo "[sql] complete"
