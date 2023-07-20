#!/bin/bash
set -e

# This script is used to perform version update of the running qdrant instance.

QDRANT_TAG=${QDRANT_TAG:-"dev"}
QDRANT_IMAGE="qdrant/qdrant:${QDRANT_TAG}"
QDRANT_CONTAINER_NAME=${QDRANT_CONTAINER_NAME:-"qdrant-node"}
BOOTSTRAP_URL=${BOOTSTRAP_URL:-""}

QDRANT_OLD_IMAGE=$QDRANT_IMAGE

CURRENT_IMAGE=$(docker inspect $QDRANT_CONTAINER_NAME | jq -r '.[0].Config.Image')

# If CURRENT_IMAGE is not empty, use this image instead of the default one
if [ ! -z "$CURRENT_IMAGE" ] && [ "$CURRENT_IMAGE" != "null" ]; then
    QDRANT_OLD_IMAGE=$CURRENT_IMAGE
fi


docker stop -t 10 ${QDRANT_CONTAINER_NAME} || true

docker rm ${QDRANT_CONTAINER_NAME} || true

docker rmi -f ${QDRANT_OLD_IMAGE} || true

RUN_ARGS=""

# Set bootstrap param is BOOTSTRAP_URL is specified
if [ ! -z "$BOOTSTRAP_URL" ]; then
    RUN_ARGS="${RUN_ARGS} --bootstrap ${BOOTSTRAP_URL}"
fi


docker run \
    -d \
    --network host \
    --restart unless-stopped \
    -v $(pwd)/storage:/qdrant/storage \
    -e QDRANT__CLUSTER__ENABLE=true \
    --name ${QDRANT_CONTAINER_NAME} \
    ${QDRANT_IMAGE} \
    ./entrypoint.sh ${RUN_ARGS}
