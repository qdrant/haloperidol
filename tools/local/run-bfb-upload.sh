#!/bin/bash

set -euo pipefail

BFB_CONTAINER_NAME="bfb-upload"
BFB_IMAGE_NAME="qdrant/bfb:latest"

QDRANT_API_KEY=${QDRANT_API_KEY:-""}

QDRANT_URIS=( ${QDRANT_HOSTS[@]/#/https://} )
QDRANT_URIS=( ${QDRANT_URIS[@]/%/:6334} )

BFB_PARAMETERS=" \
    ${QDRANT_URIS[@]/#/--uri } \
    --replication-factor 2 \
    --keywords 10 \
    --dim 768 \
    -n 1000000000 \
    --batch-size 250 \
    --threads 1 \
    --parallel 1 \
    --wait-on-upsert \
    --create-if-missing \
    --quantization scalar \
    --timing-threshold 1 \
    --on-disk-vectors true \
    --max-id 200000 \
    --delay 300 \
    --timeout 30
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

sleep 5

EXIT_CODE=$(docker inspect ${BFB_CONTAINER_NAME} --format='{{.State.ExitCode}}')

if [ "$EXIT_CODE" != "0" ]; then
    echo "BFB failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi
