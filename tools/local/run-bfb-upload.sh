#!/bin/bash

set -euo pipefail

BFB_CONTAINER_NAME="bfb-upload"
BFB_IMAGE_NAME="qdrant/bfb:dev"

QDRANT_API_KEY=${QDRANT_API_KEY:-""}

# shellcheck disable=SC2206
QDRANT_URIS=( ${QDRANT_HOSTS[@]/#/https://} )
# shellcheck disable=SC2206
QDRANT_URIS=( ${QDRANT_URIS[@]/%/:6334} )

# shellcheck disable=SC2124
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
    --delay 1000 \
    --timeout 30 \
    --retry 4 \
    --retry-interval 1 \
"

BFB_ENV_VARS="RUST_LOG=debug,h2=info,tower=info,h2::proto=debug"

docker stop -t 10 ${BFB_CONTAINER_NAME} || true

docker rm ${BFB_CONTAINER_NAME} || true

docker rmi -f ${BFB_IMAGE_NAME} || true

touch bfb-upload.log

docker run \
    -d \
    --network host \
    --name "$BFB_CONTAINER_NAME" \
    -e "QDRANT_API_KEY=$QDRANT_API_KEY" \
    -v "$(pwd)/bfb-upload.log:/bfb/upload.log" \
    ${BFB_IMAGE_NAME} \
    sh -c "${BFB_ENV_VARS} ./bfb ${BFB_PARAMETERS} | tee /bfb/upload.log"

sleep 5

EXIT_CODE=$(docker inspect ${BFB_CONTAINER_NAME} --format='{{.State.ExitCode}}')

if [ "$EXIT_CODE" != "0" ]; then
    echo "BFB failed with exit code $EXIT_CODE"
    exit "$EXIT_CODE"
fi
