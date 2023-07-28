#!/usr/bin/env bash

set -euo pipefail

BFB_IMAGE_NAME="${BFB_IMAGE_NAME:-qdrant/bfb}"
BFB_IMAGE_TAG="${BFB_IMAGE_TAG:-latest}"

BFB_IMAGE="${BFB_IMAGE:-$BFB_IMAGE_NAME:$BFB_IMAGE_TAG}"
BFB_CONTAINER_NAME="${BFB_CONTAINER_NAME:-bfb-upload}"

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
    --replication-factor 2
    --keywords 10
    --dim 768
    -n 1000000000
    --batch-size 50
    --threads 1
    --parallel 1
    --wait-on-upsert
    --create-if-missing
    --quantization scalar
    --timing-threshold 1
    --on-disk-vectors true
    --max-id 200000
    --delay 100
)


docker stop -t 10 "$BFB_CONTAINER_NAME" || true
docker rm "$BFB_CONTAINER_NAME" || true
docker rmi -f "$BFB_IMAGE_NAME" || true

docker run \
    -d \
    --name "$BFB_CONTAINER_NAME" \
    --network host \
    -e QDRANT_API_KEY="$QDRANT_API_KEY" \
    "$BFB_IMAGE" \
    ./bfb "${BFB_PARAMETERS[@]}"


sleep 1


EXIT_CODE="$(docker inspect "$BFB_CONTAINER_NAME" --format='{{ .State.ExitCode }}')"

if [[ $EXIT_CODE != 0 ]]
then
    echo "bfb failed with exit code $EXIT_CODE" >&2
    exit "$EXIT_CODE"
fi
