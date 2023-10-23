#!/bin/bash

# Usage: tools/run-benchmarks.sh "deep-image-96-angular" "new-benchmark-server"

set -e
set -x

SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
export CLOUD_NAME=${CLOUD_NAME:-"custom"}

DATASETS=("glove-100-angular" "deep-image-96" "gist-960-euclidean")
VECTOR_DBS=("qdrant" "milvus" "elasticsearch" "weaviate" "redis")
BRANCH="feat/benchmark-upgrades"

# Run only while setting up new benchmark server and client:
# for dataset in "${DATASETS[@]}"; do
#     SERVER_NAME=benchmark-client-${dataset} bash -x $SCRIPT_PATH/clouds/$CLOUD_NAME/create_and_install.sh
#     SERVER_NAME=benchmark-server-${dataset} bash -x $SCRIPT_PATH/clouds/$CLOUD_NAME/create_and_install.sh
# done

DATASET=$1
SERVER_NAME=$2

# replace "server" with "client" if 3rd argument is not passed
CLIENT_NAME=${3:-"${SERVER_NAME/server/client}"}
PRIVATE_SERVER_IP=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh $SERVER_NAME)

for VECTOR_DB in "${VECTOR_DBS[@]}"; do
    echo Running benchmark for ${vdb} on ${DATASET}

    RUN_SCRIPT="${SCRIPT_PATH}/local/setup-benchmark-server.sh" \
        ENV_CONTEXT="${VECTOR_DB@A} ${BRANCH@A}" \
        SERVER_NAME=${SERVER_NAME} \
        bash -x $SCRIPT_PATH/run_remote.sh

    RUN_SCRIPT="${SCRIPT_PATH}/local/setup-benchmark-client.sh" \
        ENV_CONTEXT="${VECTOR_DB@A} ${BRANCH@A} ${PRIVATE_SERVER_IP@A} ${DATASET@A}" \
        SERVER_NAME=${CLIENT_NAME} \
        bash -x $SCRIPT_PATH/run_remote.sh
done
