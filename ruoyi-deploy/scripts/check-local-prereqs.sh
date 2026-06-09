#!/usr/bin/env bash

set -euo pipefail

echo "Checking local deployment prerequisites..."

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[ok] $cmd -> $(command -v "$cmd")"
  else
    echo "[missing] $cmd"
  fi
}

check_cmd docker
check_cmd helm
check_cmd kubectl

if [ -x /Applications/Docker.app/Contents/Resources/bin/kubectl ]; then
  echo "[ok] docker-desktop kubectl -> /Applications/Docker.app/Contents/Resources/bin/kubectl"
fi

if command -v docker >/dev/null 2>&1; then
  if docker ps >/dev/null 2>&1; then
    echo "[ok] docker daemon reachable"
  else
    echo "[warn] docker command exists but daemon is not reachable from current shell"
  fi
fi

if [ -x /Applications/Docker.app/Contents/Resources/bin/kubectl ]; then
  if /Applications/Docker.app/Contents/Resources/bin/kubectl config current-context >/dev/null 2>&1; then
    echo "[ok] kubectl context is configured"
    /Applications/Docker.app/Contents/Resources/bin/kubectl config current-context
  else
    echo "[warn] kubectl exists but kube context is not ready"
  fi
fi
