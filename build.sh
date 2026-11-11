#!/bin/bash
# =============================================================================
# dev-python-env — build the dev image for a given environment file.
#
#   ./build.sh envs/<chapter>.yml
#
# The image/container names and the port are derived from the file name:
#   envs/chapter06.yml  ->  image mlewp-chapter06:latest,
#                           container mlewp-chapter06, port 2222.
#
# The resolved variables are written to .env, so bare `docker compose` commands
# (exec/down/logs) afterwards target the same chapter.
# =============================================================================
set -euo pipefail

ENV_FILE="${1:?usage: ./build.sh envs/<chapter>.yml}"
[ -f "$ENV_FILE" ] || { echo "no such env file: $ENV_FILE"; exit 1; }

base="$(basename "$ENV_FILE" .yml)"

PROJECT_NAME="${PROJECT_NAME:-mlewp}"
PORT="${PORT:-2222}"
IMAGE="${PROJECT_NAME}-${base}:latest"
CONTAINER="${PROJECT_NAME}-${base}"

export ENV_FILE IMAGE CONTAINER PORT PROJECT_NAME

# Persist the resolved state so later bare `docker compose ...` resolves the
# same chapter (compose reads .env when no shell var is set).
cat > .env <<EOF
PROJECT_NAME=${PROJECT_NAME}
PORT=${PORT}
ENV_FILE=${ENV_FILE}
IMAGE=${IMAGE}
CONTAINER=${CONTAINER}
EOF

docker compose build
echo "done: ${IMAGE}"
