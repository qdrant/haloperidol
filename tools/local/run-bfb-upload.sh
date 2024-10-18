#!/bin/bash

set -euo pipefail

QC_NAME=${QC_NAME:-"qdrant-chaos-testing"}
EXTRA_PARAMS=""

if [ "$QC_NAME" == "qdrant-chaos-testing" ]; then
    BFB_CONTAINER_NAME="bfb-upload"
elif [ "$QC_NAME" == "qdrant-chaos-testing-debug" ]; then
    BFB_CONTAINER_NAME="bfb-upload-debug"
elif [ "$QC_NAME" == "qdrant-chaos-testing-three" ]; then
    BFB_CONTAINER_NAME="bfb-upload-three"
    EXTRA_PARAMS="--write-consistency-factor 2"
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
    --replication-factor 2 \
    --shards 3 \
    --keywords 10 \
    --timestamp-payload \
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
    $EXTRA_PARAMS
"

BFB_ENV_VARS="RUST_BACKTRACE=full RUST_LOG=debug,h2=info,tower=info,h2::proto=debug"

docker stop -t 10 ${BFB_CONTAINER_NAME} || true

docker rm ${BFB_CONTAINER_NAME} || true

docker rmi -f ${BFB_IMAGE_NAME} || true

touch "$BFB_CONTAINER_NAME.log" # create file so that docker doesn't create a dir instead

docker run \
    -d \
    --network host \
    --name "$BFB_CONTAINER_NAME" \
    -e "QDRANT_API_KEY=$QDRANT_API_KEY" \
    -v "$(pwd)/$BFB_CONTAINER_NAME.log:/bfb/upload.log" \
    ${BFB_IMAGE_NAME} \
    bash -c "set -eou pipefail; while true; do ${BFB_ENV_VARS} ./bfb ${BFB_PARAMETERS} 2>&1 | tee /bfb/upload.log; echo \"${BFB_CONTAINER_NAME} stopped\"; sleep 100; done"

sleep 5

EXIT_CODE=$(docker inspect ${BFB_CONTAINER_NAME} --format='{{.State.ExitCode}}')

if [ "$EXIT_CODE" != "0" ]; then
    echo "BFB failed with exit code $EXIT_CODE"
    exit "$EXIT_CODE"
fi
