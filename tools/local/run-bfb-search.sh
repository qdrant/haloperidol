#!/bin/bash

set -euo pipefail

QC_NAME=${QC_NAME:-"qdrant-chaos-testing"}

if [ "$QC_NAME" == "qdrant-chaos-testing" ]; then
    BFB_CONTAINER_NAME="bfb-search"
elif [ "$QC_NAME" == "qdrant-chaos-testing-debug" ]; then
    BFB_CONTAINER_NAME="bfb-search-debug"
else
    echo "Unexpected QdrantCluster $QC_NAME"
fi

BFB_IMAGE_NAME="qdrant/bfb:dev"

QDRANT_API_KEY=${QDRANT_API_KEY:-""}

# shellcheck disable=SC2206
QDRANT_URIS=( ${QDRANT_HOSTS[@]/#/https://} )
# shellcheck disable=SC2206
QDRANT_URIS=( ${QDRANT_URIS[@]/%/:6334} )

# shellcheck disable=SC2124
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
    --retry 4 \
    --retry-interval 1 \
"

BFB_ENV_VARS="RUST_LOG=debug,h2=info,tower=info,h2::proto=debug"

docker stop -t 10 ${BFB_CONTAINER_NAME} || true

docker rm ${BFB_CONTAINER_NAME} || true

touch "$BFB_CONTAINER_NAME.log"

docker run \
    -d \
    --network host \
    --name "$BFB_CONTAINER_NAME" \
    -e "QDRANT_API_KEY=$QDRANT_API_KEY" \
    -v "$(pwd)/$BFB_CONTAINER_NAME.log:/bfb/search.log" \
    ${BFB_IMAGE_NAME} \
    bash -c "set -e; while true; do ${BFB_ENV_VARS} ./bfb ${BFB_PARAMETERS} | tee /bfb/search.log; if [ $? -ne 0 ]; then echo \"bfb command crashed. Exiting loop.\"; break; fi; sleep 10; done"

