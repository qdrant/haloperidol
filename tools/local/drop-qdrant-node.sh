#!/bin/bash
set -e


QDRANT_CONTAINER_NAME=${QDRANT_CONTAINER_NAME:-"qdrant-node"}
docker stop -t 0 ${QDRANT_CONTAINER_NAME}

docker rm -f ${QDRANT_CONTAINER_NAME} || true