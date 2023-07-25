#!/bin/bash
set -e

# This script is used to perform version update of the running qdrant instance.

QDRANT_TAG=${QDRANT_TAG:-"dev"}
QDRANT_IMAGE="qdrant/qdrant:${QDRANT_TAG}"
QDRANT_CONTAINER_NAME=${QDRANT_CONTAINER_NAME:-"qdrant-node"}
QDRANT_API_KEY=${QDRANT_API_KEY:-""}

BOOTSTRAP_URL=${BOOTSTRAP_URL:-""}
NODE_URI=${NODE_URI:-""}
KILL_STORAGES=${KILL_STORAGES:-"false"}

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

if [ ! -z "$NODE_URI" ]; then
    RUN_ARGS="${RUN_ARGS} --uri ${NODE_URI}"
fi

# Set bootstrap param is BOOTSTRAP_URL is specified
if [ ! -z "$BOOTSTRAP_URL" ]; then
    RUN_ARGS="${RUN_ARGS} --bootstrap ${BOOTSTRAP_URL}"
fi

if [ "$KILL_STORAGES" == "true" ]; then
    rm -rf $(pwd)/storage
fi

API_KEY_ENV=""

if [ ! -z "$QDRANT_API_KEY" ]; then
    API_KEY_ENV="-e QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY}"
fi

docker run \
    -d \
    --network host \
    --restart unless-stopped \
    -v $(pwd)/storage:/qdrant/storage \
    -e QDRANT__CLUSTER__ENABLED=true \
    ${API_KEY_ENV} \
    --name ${QDRANT_CONTAINER_NAME} \
    ${QDRANT_IMAGE} \
    ./entrypoint.sh ${RUN_ARGS}
