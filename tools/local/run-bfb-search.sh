#!/bin/bash

set -euo pipefail

QC_NAME=${QC_NAME:-"qdrant-chaos-testing"}

if [ "$QC_NAME" == "qdrant-chaos-testing" ]; then
    BFB_CONTAINER_NAME="bfb-search"
elif [ "$QC_NAME" == "qdrant-chaos-testing-debug" ]; then
    BFB_CONTAINER_NAME="bfb-search-debug"
elif [ "$QC_NAME" == "qdrant-chaos-testing-three" ]; then
    BFB_CONTAINER_NAME="bfb-search-three"
else
    echo "Unexpected QdrantCluster $QC_NAME"
    exit 1
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
    --sparse-dim 3000 \
    --sparse-vectors 0.05 \
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

BFB_ENV_VARS="RUST_BACKTRACE=full RUST_LOG=debug,h2=info,tower=info,h2::proto=debug"

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
    bash -c "set -eou pipefail; while true; do ${BFB_ENV_VARS} ./bfb ${BFB_PARAMETERS} 2>&1; done"

