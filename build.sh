#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="mod-proxy-msrpc-build:bionic"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$ROOT_DIR/out"

mkdir -p "$OUT_DIR"

if command -v docker >/dev/null 2>&1; then
  docker build -f "$ROOT_DIR/Dockerfile.build" -t "$IMAGE_TAG" "$ROOT_DIR"

  docker run --rm \
    -u build \
    -v "$ROOT_DIR":/src \
    -v "$OUT_DIR":/out \
    "$IMAGE_TAG" \
    bash -lc '/src/scripts/build_in_container.sh'
else
  echo "WARN: docker not found, running host fallback build (non-bionic; compatibility checks may fail)" >&2
  SRC_DIR="$ROOT_DIR" OUT_DIR="$OUT_DIR" WORK_DIR="${WORK_DIR:-/tmp/mod_proxy_msrpc-build}" \
    "$ROOT_DIR/scripts/build_in_container.sh"
fi
