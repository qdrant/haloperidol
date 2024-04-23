#!/bin/bash

set -euo pipefail

BFB_CONTAINER_NAME="bfb-search"
BFB_IMAGE_NAME="qdrant/bfb:latest"

QDRANT_API_KEY=${QDRANT_API_KEY:-""}

QDRANT_URIS=( ${QDRANT_HOSTS[@]/#/https://} )
QDRANT_URIS=( ${QDRANT_URIS[@]/%/:6334} )

BFB_PARAMETERS=" \
    ${QDRANT_URIS[@]/#/--uri } \
    --keywords 10 \
    --dim 768 \
    -n 1000 \
    --threads 1 \
    --parallel 1 \
    --quantization scalar \
    --timing-threshold 1 \
    --timeout 30 \
    --skip-create \
    --skip-upload \
    --skip-wait-index \
    --search \
    --search-limit 10 \
    --quantization-rescore true \
"


docker stop -t 10 ${BFB_CONTAINER_NAME} || true

docker rm ${BFB_CONTAINER_NAME} || true

touch bfb-search-error.log

docker run \
    -d \
    --network host \
    --name ${BFB_CONTAINER_NAME} \
    -e QDRANT_API_KEY=${QDRANT_API_KEY} \
    -v $(pwd)/bfb-search-error.log:/bfb/search-error.log \
    ${BFB_IMAGE_NAME} \
    bash -c "while true; ./bfb ${BFB_PARAMETERS} 2>> /bfb/search-error.log; do sleep 10; done"

