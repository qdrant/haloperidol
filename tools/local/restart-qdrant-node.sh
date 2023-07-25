#!/bin/bash
set -e


QDRANT_CONTAINER_NAME=${QDRANT_CONTAINER_NAME:-"qdrant-node"}
docker restart -t 0 ${QDRANT_CONTAINER_NAME}

