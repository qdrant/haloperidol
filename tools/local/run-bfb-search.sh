#!/bin/bash

set -e

QDRANT_HOSTS=( $QDRANT_HOSTS ) # Unescaped parameter expansion

BFB_CONTAINER_NAME="bfb-search"
BFB_IMAGE_NAME="qdrant/bfb:latest"

QDRANT_API_KEY=${QDRANT_API_KEY:-""}

QDRANT_URIS=( ${QDRANT_HOSTS[@]/#/--uri } ) # Unescaped parameter expansion


BFB_PARAMETERS=" \
    ${QDRANT_URIS} \
    --keywords 10 \
    --dim 768 \
    -n 10000 \
    --threads 1 \
    --parallel 1 \
    --quantization scalar \
    --timing-threshold 1 \
    --skip-create \
    --skip-upload \
    --skip-wait-index \
    --search \
    --search-limit 10 \
    --quantization-rescore true
"


docker stop -t 10 ${BFB_CONTAINER_NAME} || true

docker rm ${BFB_CONTAINER_NAME} || true

docker run \
    -d \
    --network host \
    --name ${BFB_CONTAINER_NAME} \
    -e QDRANT_API_KEY=${QDRANT_API_KEY} \
    ${BFB_IMAGE_NAME} \
    ./bfb ${BFB_PARAMETERS}

