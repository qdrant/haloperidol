#!/bin/bash
set -e


QDRANT_CONTAINER_NAME=${QDRANT_CONTAINER_NAME:-"qdrant-node"}
docker stop -t 0 ${QDRANT_CONTAINER_NAME} || true

docker rm -f ${QDRANT_CONTAINER_NAME} || true

KILL_STORAGES=${KILL_STORAGES:-"false"}

if [[ "$KILL_STORAGES" == "true" ]]
then
    rm -rf storage
fi

