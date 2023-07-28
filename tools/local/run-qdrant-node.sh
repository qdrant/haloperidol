#!/usr/bin/env bash

set -euo pipefail

# This script is used to perform version update of the running qdrant instance.

QDRANT_IMAGE_NAME="${QDRANT_IMAGE_NAME:-qdrant/qdrant}"
QDRANT_IMAGE_TAG="${QDRANT_IMAGE_TAG:-skip-outdated-raft-heartbeats}"

QDRANT_IMAGE="${QDRANT_IMAGE:-$QDRANT_IMAGE_NAME:$QDRANT_IMAGE_TAG}"
QDRANT_CONTAINER_NAME="${QDRANT_CONTAINER_NAME:-qdrant}"

QDRANT_API_KEY="${QDRANT_API_KEY-}"
KILL_STORAGES="${KILL_STORAGES:-0}"

QDRANT_ARGS=( "$@" )


docker stop -t 10 "$QDRANT_CONTAINER_NAME" || true
docker rm "$QDRANT_CONTAINER_NAME" || true


CURRENT_IMAGE="$(docker inspect "$QDRANT_CONTAINER_NAME" | jq -r '.[0].Config.Image')"

docker rmi -f "${CURRENT_IMAGE:-$QDRANT_IMAGE}" || true


if (( KILL_STORAGES ))
then
    rm -rf "$PWD"/storage
fi


declare DOCKER_ARGS=()

if [[ $QDRANT_API_KEY ]]
then
    DOCKER_ARGS+=( -e QDRANT__SERVICE__API_KEY="$QDRANT_API_KEY" )
fi

docker run \
    -d \
    --name "$QDRANT_CONTAINER_NAME" \
    --network host \
    -v "$PWD"/storage:/qdrant/storage \
    -e QDRANT__CLUSTER__ENABLED=true \
    "${DOCKER_ARGS[@]}"
    "$QDRANT_IMAGE" \
    ./entrypoint.sh "${QDRANT_ARGS[@]}"
