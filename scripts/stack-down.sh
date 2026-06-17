#!/bin/zsh
set -euo pipefail

ENV_NAME="${1:-dev}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_DIR="${ROOT_DIR}/.local/run/${ENV_NAME}"

if [[ -d "${PID_DIR}" ]]; then
  for pid_file in "${PID_DIR}"/*.pid; do
    [[ -f "${pid_file}" ]] || continue
    pid="$(cat "${pid_file}")"
    kill "${pid}" >/dev/null 2>&1 || true
    rm -f "${pid_file}"
  done
fi

if docker info >/dev/null 2>&1; then
  docker compose -f "${ROOT_DIR}/ops/docker/docker-compose.observability.yml" down
else
  echo "Docker daemon is not running, skip observability stack shutdown"
fi
echo "Environment ${ENV_NAME} stopped."
