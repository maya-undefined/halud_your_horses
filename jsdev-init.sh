# jsdev-init.sh
#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${JSDEV_CONFIG:-$HOME/.jsdevrc}"
if [ ! -f "$CONFIG_FILE" ]; then
  mkdir -p "$HOME/.jsdev"
  cat >"$CONFIG_FILE" <<'EOF'
# jsdev config defaults.
# You can override any of these via environment variables:
#   JSDEV_BACKEND, JSDEV_BASE_IMAGE, JSDEV_GLOBAL_DIR, JSDEV_DOCKERFILE_EXT

: "${JSDEV_BACKEND:=podman}"
: "${JSDEV_BASE_IMAGE:=js-dev:base}"
: "${JSDEV_GLOBAL_DIR:=$HOME/.jsdev}"
: "${JSDEV_DOCKERFILE_EXT:=$HOME/.jsdev/Dockerfile.ext}"
EOF
fi

# shellcheck source=/dev/null
. "$CONFIG_FILE"

: "${JSDEV_BACKEND:=$podman}"
: "${JSDEV_BASE_IMAGE:=js-dev:base}"
: "${JSDEV_GLOBAL_DIR:=$HOME/.jsdev}"
: "${JSDEV_DOCKERFILE_EXT:=$HOME/.jsdev/Dockerfile.ext}"

OCI_BIN="$JSDEV_BACKEND"

if ! command -v "$OCI_BIN" >/dev/null 2>&1; then
  echo "Error: backend '$OCI_BIN' not found in PATH (expected docker or podman)" >&2
  exit 1
fi

# Args:
#   PROJECT_DIR [IMAGE_TAG]
if [ $# -gt 2 ]; then
  echo "Usage: $(basename "$0") [PROJECT_DIR] [IMAGE_TAG]" >&2
  exit 1
fi

# Default PROJECT_DIR to '.' if not given
PROJECT_DIR="${1:-.}"

# Normalize to absolute path
mkdir -p "$PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Default IMAGE_TAG to '<basename>-dev' if not given
if [ $# -ge 2 ]; then
  IMAGE_TAG="$2"
else
  IMAGE_TAG="$(basename "$PROJECT_DIR")-dev"
fi


mkdir -p "$PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# 1. Ensure base dev image exists (JSDEV_BASE_IMAGE)
if ! "$OCI_BIN" image inspect "$JSDEV_BASE_IMAGE" >/dev/null 2>&1; then
  echo "[jsdev-init] Base image $JSDEV_BASE_IMAGE not found, building it..."

  BASE_DIR="${JSDEV_GLOBAL_DIR}/base"
  mkdir -p "$BASE_DIR"

  cat > "${BASE_DIR}/Dockerfile" <<'EOF'
FROM node:22-slim

# Basic OS deps
RUN apt-get update && apt-get install -y \
    git build-essential \
 && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=development
WORKDIR /workspace

# Optional: global helpers
RUN npm install -g pnpm npm-check-updates
RUN apt-get update
RUN apt-get install -y tmux
EOF

  "$OCI_BIN" build -t "$JSDEV_BASE_IMAGE" "${BASE_DIR}"
fi

# 2. Create project Dockerfile if missing
if [ ! -f "${PROJECT_DIR}/Dockerfile" ]; then
  echo "[jsdev-init] Creating project Dockerfile in ${PROJECT_DIR}"

  if ls "${PROJECT_DIR}"/package*.json >/dev/null 2>&1; then
    cat > "${PROJECT_DIR}/Dockerfile" <<'EOF'
ARG JSDEV_BASE_IMAGE=js-dev:base
FROM ${JSDEV_BASE_IMAGE}

WORKDIR /workspace/project

COPY package*.json ./
RUN if [ -f package.json ]; then npm ci; fi
EOF
  else
    cat > "${PROJECT_DIR}/Dockerfile" <<'EOF'
ARG JSDEV_BASE_IMAGE=js-dev:base
FROM ${JSDEV_BASE_IMAGE}

WORKDIR /workspace/project
EOF
  fi

  # Append user extension if configured and exists
  if [ -n "${JSDEV_DOCKERFILE_EXT:-}" ] && [ -f "${JSDEV_DOCKERFILE_EXT}" ]; then
    cat "${JSDEV_DOCKERFILE_EXT}" >> "${PROJECT_DIR}/Dockerfile"
  fi

  # Always end with a default CMD
  cat >> "${PROJECT_DIR}/Dockerfile" <<'EOF'

CMD ["bash"]
EOF
fi



# 3. Remember the image tag for this project
IMAGE_FILE="${PROJECT_DIR}/.jsdev-image"

# Refuse to overwrite if it's a symlink (could point outside the project)
if [ -L "$IMAGE_FILE" ]; then
  echo "[jsdev-init] ERROR: $IMAGE_FILE is a symlink; refusing to overwrite." >&2
  echo "[jsdev-init]        Remove or replace it with a regular file and re-run." >&2
  exit 1
fi

# Also refuse if it exists and is not a regular file
if [ -e "$IMAGE_FILE" ] && [ ! -f "$IMAGE_FILE" ]; then
  echo "[jsdev-init] ERROR: $IMAGE_FILE exists but is not a regular file; refusing to overwrite." >&2
  exit 1
fi

echo "${IMAGE_TAG}" > "$IMAGE_FILE"

# 4. Initial build (passing base image as build-arg)
echo "[jsdev-init] Building image ${IMAGE_TAG} from ${PROJECT_DIR}"
"$OCI_BIN" build \
  --build-arg "JSDEV_BASE_IMAGE=${JSDEV_BASE_IMAGE}" \
  -t "${IMAGE_TAG}" \
  "${PROJECT_DIR}"

echo "[jsdev-init] Done."
echo "  Project dir: ${PROJECT_DIR}"
echo "  Image tag:   ${IMAGE_TAG}"
echo
echo "Next: run jsdev-shell.sh ${PROJECT_DIR} to work inside the container."

