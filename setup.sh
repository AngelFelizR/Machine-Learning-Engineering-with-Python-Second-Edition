#!/bin/bash
# =============================================================================
# dev-conda-env — start the dev container for a given environment file and
# install your SSH public key.
#
#   ./setup.sh envs/<chapter>.yml
#
# Add once to ~/.ssh/config (same Host for every chapter — only one runs at a
# time, all on port 2222):
#
#   Host mlewp
#       HostName 127.0.0.1
#       User dev
#       Port 2222
#       IdentityFile ~/.ssh/id_ed25519
# =============================================================================
set -euo pipefail

ENV_FILE="${1:?usage: ./setup.sh envs/<chapter>.yml}"
[ -f "$ENV_FILE" ] || { echo "no such env file: $ENV_FILE"; exit 1; }

base="$(basename "$ENV_FILE" .yml)"

PROJECT_NAME="${PROJECT_NAME:-mlewp}"
PORT="${PORT:-2222}"
IMAGE="${PROJECT_NAME}-${base}:latest"
CONTAINER="${PROJECT_NAME}-${base}"

export ENV_FILE IMAGE CONTAINER PORT PROJECT_NAME

# Persist the resolved state so later bare `docker compose down`/`exec` work.
cat > .env <<EOF
PROJECT_NAME=${PROJECT_NAME}
PORT=${PORT}
ENV_FILE=${ENV_FILE}
IMAGE=${IMAGE}
CONTAINER=${CONTAINER}
EOF

# The Positron REH volume is external (seeded by hand once); create the empty
# one if it is not there yet -- the client downloads into it.
docker volume create positron-server >/dev/null

# Build if the image is not there yet (first run), then start.
if [ "$(docker images -q "$IMAGE" 2>/dev/null)" = "" ]; then
    echo "building ${IMAGE} (first run)..."
    ./build.sh "$ENV_FILE"
fi

docker compose up -d

echo "Waiting for SSH service to be ready..."
sleep 3

if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" = "true" ]; then
    docker cp ~/.ssh/id_ed25519.pub "$CONTAINER:/home/dev/.ssh/authorized_keys"
    docker exec -u 0 "$CONTAINER" chown 1000:1000 /home/dev/.ssh/authorized_keys
    docker exec -u 0 "$CONTAINER" chmod 600 /home/dev/.ssh/authorized_keys
    echo "Ready! Connect with: ssh mlewp"
else
    echo "ERROR: The container $CONTAINER stopped unexpectedly."
    echo "Check the reasons by running: docker logs $CONTAINER"
    exit 1
fi
