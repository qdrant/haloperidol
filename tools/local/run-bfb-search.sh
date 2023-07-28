#!/usr/bin/env bash

set -euo pipefail

BFB_IMAGE_NAME="${BFB_IMAGE_NAME:-qdrant/bfb}"
BFB_IMAGE_TAG="${BFB_IMAGE_TAG:-latest}"

BFB_IMAGE="${BFB_IMAGE:-$BFB_IMAGE_NAME:$BFB_IMAGE_TAG}"
BFB_CONTAINER_NAME="${BFB_CONTAINER_NAME:-bfb-search}"

QDRANT_API_KEY="${QDRANT_API_KEY-}"


if (( $# == 0 ))
then
    echo "TODO" >&2
    exit 1
fi


BFB_PARAMETERS=()

for QDRANT_HOST in "$@"
do
    BFB_PARAMETERS+=( --uri "http://$QDRANT_HOST:6334" )
done

BFB_PARAMETERS+=(
    --keywords 10
    --dim 768
    -n 1000
    --threads 1
    --parallel 1
    --quantization scalar
    --timing-threshold 1
    --skip-create
    --skip-upload
    --skip-wait-index
    --search
    --search-limit 10
    --quantization-rescore true
)


docker stop -t 10 "$BFB_CONTAINER_NAME" || true
docker rm "$BFB_CONTAINER_NAME" || true

docker run \
    -d \
    --name "$BFB_CONTAINER_NAME" \
    --network host \
    -e QDRANT_API_KEY="$QDRANT_API_KEY" \
    "$BFB_IMAGE" \
    bash -c "while true; do ./bfb ${BFB_PARAMETERS[*]@Q} || exit $?; sleep 10; done"
