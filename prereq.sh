#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root: sudo ./prereq.sh" >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "Unsupported host: /etc/os-release missing" >&2
  exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "This script supports Ubuntu only (detected: ${ID:-unknown})" >&2
  exit 1
fi

echo "==> Installing base packages"
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg lsb-release software-properties-common \
  git make bash

if ! command -v docker >/dev/null 2>&1; then
  echo "==> Installing Docker CE"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  ARCH="$(dpkg --print-architecture)"
  CODENAME="${VERSION_CODENAME:-$(lsb_release -cs)}"
  echo \
    "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "==> Docker already installed"
fi

TARGET_USER="${SUDO_USER:-${USER:-}}"
if [[ -n "$TARGET_USER" && "$TARGET_USER" != "root" ]]; then
  if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx docker; then
    echo "==> User $TARGET_USER already in docker group"
  else
    echo "==> Adding $TARGET_USER to docker group"
    usermod -aG docker "$TARGET_USER"
    echo "NOTE: log out/in (or run 'newgrp docker') before using docker without sudo."
  fi
fi

echo "==> Validating Docker CLI"
docker --version

echo "==> Host is ready. Next step: ./build.sh"
