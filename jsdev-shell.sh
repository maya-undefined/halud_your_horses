# jsdev-shell.sh
#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${JSDEV_CONFIG:-$HOME/.jsdevrc}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck source=/dev/null
  . "$CONFIG_FILE"
fi

: "${JSDEV_BACKEND:=docker}"
: "${JSDEV_BASE_IMAGE:=js-dev:base}"
: "${JSDEV_GLOBAL_DIR:=$HOME/.jsdev}"
: "${JSDEV_DOCKERFILE_EXT:=$HOME/.jsdev/Dockerfile.ext}"

OCI_BIN="$JSDEV_BACKEND"

if ! command -v "$OCI_BIN" >/dev/null 2>&1; then
  echo "Error: backend '$OCI_BIN' not found in PATH (expected docker or podman)" >&2
  exit 1
fi

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $(basename "$0") PROJECT_DIR [IMAGE_TAG]" >&2
  exit 1
fi

PROJECT_DIR="$1"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
IMAGE_TAG="${2:-}"

if [ -z "${IMAGE_TAG}" ]; then
  if [ -f "${PROJECT_DIR}/.jsdev-image" ]; then
    IMAGE_TAG="$(cat "${PROJECT_DIR}/.jsdev-image")"
  else
    IMAGE_TAG="$(basename "${PROJECT_DIR}")-dev"
  fi
fi

# If the image doesn't exist, build it (respecting base image)
if ! "$OCI_BIN" image inspect "${IMAGE_TAG}" >/dev/null 2>&1; then
  echo "[jsdev-shell] Image ${IMAGE_TAG} not found, building..."
  "$OCI_BIN" build \
    --build-arg "JSDEV_BASE_IMAGE=${JSDEV_BASE_IMAGE}" \
    -t "${IMAGE_TAG}" \
    "${PROJECT_DIR}"
fi

# Per-project node_modules volume (hashed path -> short id)
VOL_ID="$(printf '%s' "$PROJECT_DIR" | sha1sum | cut -c1-12)"
VOL_NAME="jsdev_nm_${VOL_ID}"

echo "[jsdev-shell] Using image:   ${IMAGE_TAG}"
echo "[jsdev-shell] Project dir:   ${PROJECT_DIR}"
echo "[jsdev-shell] node_modules:  volume ${VOL_NAME} -> /workspace/project/node_modules"

"$OCI_BIN" run --rm -it \
  -v "${PROJECT_DIR}":/workspace/project \
  -v "${VOL_NAME}":/workspace/project/node_modules \
  -w /workspace/project \
  "${IMAGE_TAG}" \
  bash

