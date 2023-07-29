#!/usr/bin/env bash

set -euo pipefail

QDRANT_CONTAINER_NAME="${1:-qdrant}"

docker restart -t 0 "$QDRANT_CONTAINER_NAME"
sleep 1
docker restart -t 0 "$QDRANT_CONTAINER_NAME"
