#!/bin/bash

set -euo pipefail

BFB_CONTAINER_NAME="bfb-upload"
BFB_IMAGE_NAME="qdrant/bfb:latest"

QDRANT_API_KEY=${QDRANT_API_KEY:-""}


BFB_PARAMETERS=" \
    ${QDRANT_HOSTS[@]/#/--uri } \
    --replication-factor 2 \
    --keywords 10 \
    --dim 768 \
    -n 1000000000 \
    --batch-size 10 \
    --threads 1 \
    --parallel 1 \
    --wait-on-upsert \
    --quantization scalar \
    --timing-threshold 1 \
    --max-id 100000 \
    --delay 200
"


docker stop -t 10 ${BFB_CONTAINER_NAME} || true

docker rm ${BFB_CONTAINER_NAME} || true

docker rmi -f ${BFB_IMAGE_NAME} || true


docker run \
    -d \
    --network host \
    --name ${BFB_CONTAINER_NAME} \
    -e QDRANT_API_KEY=${QDRANT_API_KEY} \
    ${BFB_IMAGE_NAME} \
    ./bfb ${BFB_PARAMETERS}

