# jsdev-fork.sh
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

if [ $# -ne 2 ]; then
  echo "Usage: $(basename "$0") PROJECT_DIR NEW_IMAGE_TAG" >&2
  exit 1
fi

PROJECT_DIR="$1"
NEW_IMAGE_TAG="$2"

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

if [ -f "${PROJECT_DIR}/.jsdev-image" ]; then
  SRC_IMAGE_TAG="$(cat "${PROJECT_DIR}/.jsdev-image")"
else
  SRC_IMAGE_TAG="$(basename "${PROJECT_DIR}")-dev"
fi

# Make sure source image exists
if ! "$OCI_BIN" image inspect "${SRC_IMAGE_TAG}" >/dev/null 2>&1; then
  echo "[jsdev-fork] Source image ${SRC_IMAGE_TAG} not found, building it..."
  "$OCI_BIN" build \
    --build-arg "JSDEV_BASE_IMAGE=${JSDEV_BASE_IMAGE}" \
    -t "${SRC_IMAGE_TAG}" \
    "${PROJECT_DIR}"
fi

echo "[jsdev-fork] Forking ${SRC_IMAGE_TAG} -> ${NEW_IMAGE_TAG}"
"$OCI_BIN" tag "${SRC_IMAGE_TAG}" "${NEW_IMAGE_TAG}"

# Switch project to use the new tag by default
echo "${NEW_IMAGE_TAG}" > "${PROJECT_DIR}/.jsdev-image"

echo "[jsdev-fork] Updated ${PROJECT_DIR}/.jsdev-image to ${NEW_IMAGE_TAG}"
echo "[jsdev-fork] Next: jsdev-shell.sh ${PROJECT_DIR}"
