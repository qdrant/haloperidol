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
    --shards 3 \
    --keywords 10 \
    --dim 768 \
    -n 1000000000 \
    --batch-size 100 \
    --threads 1 \
    --parallel 1 \
    --wait-on-upsert \
    --create-if-missing \
    --quantization scalar \
    --timing-threshold 1 \
    --on-disk-vectors true \
    --max-id 200000 \
    --delay 200 \
    --timeout 30
"

docker stop -t 10 ${BFB_CONTAINER_NAME} || true

docker rm ${BFB_CONTAINER_NAME} || true

docker rmi -f ${BFB_IMAGE_NAME} || true

touch bfb-upload.log

docker run \
    -d \
    --network host \
    --name ${BFB_CONTAINER_NAME} \
    -e QDRANT_API_KEY=${QDRANT_API_KEY} \
    -v $(pwd)/bfb-upload.log:/bfb/upload.log \
    ${BFB_IMAGE_NAME} \
    sh -c "./bfb ${BFB_PARAMETERS} | tee -a >(echo "$(date +"%d-%m-%y %H_%M_%S") - $(cat)" >> /bfb/upload.log)"

sleep 5

EXIT_CODE=$(docker inspect ${BFB_CONTAINER_NAME} --format='{{.State.ExitCode}}')

if [ "$EXIT_CODE" != "0" ]; then
    echo "BFB failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi
