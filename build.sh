#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="mod-proxy-msrpc-build:bionic"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$ROOT_DIR/out"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is required to run this build" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

docker build -f "$ROOT_DIR/Dockerfile.build" -t "$IMAGE_TAG" "$ROOT_DIR"

docker run --rm \
  -u build \
  -v "$ROOT_DIR":/src \
  -v "$OUT_DIR":/out \
  "$IMAGE_TAG" \
  bash -lc '/src/scripts/build_in_container.sh'
