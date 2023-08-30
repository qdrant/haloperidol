#!/bin/bash


set -e


SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ROOT_PATH=$(dirname $SCRIPT_PATH)
SCRIPT_PATH="${ROOT_PATH}"

export CLOUD_NAME=${CLOUD_NAME:-"custom"}


# SERVER_NAME=qdrant-node-1 bash -x $SCRIPT_PATH/clouds/$CLOUD_NAME/create_and_install.sh
# SERVER_NAME=qdrant-node-2 bash -x $SCRIPT_PATH/clouds/$CLOUD_NAME/create_and_install.sh
# SERVER_NAME=qdrant-node-3 bash -x $SCRIPT_PATH/clouds/$CLOUD_NAME/create_and_install.sh
# SERVER_NAME=qdrant-node-4 bash -x $SCRIPT_PATH/clouds/$CLOUD_NAME/create_and_install.sh
# SERVER_NAME=qdrant-node-5 bash -x $SCRIPT_PATH/clouds/$CLOUD_NAME/create_and_install.sh



SERVER_PRIVATE_IP_1=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-1)
# SERVER_PRIVATE_IP_2=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-2)
# SERVER_PRIVATE_IP_3=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-3)

export KILL_STORAGES="true"

export QDRANT_TAG="shard-snapshot-lock-free-shard-read-ops-1"
# export QDRANT_TAG="shard-snapshot-priority-local-only"


export QDRANT_API_KEY=${QDRANT_API_KEY:-""}

# ToDo: start qdrant cluster on all nodes

export NODE_URI="http://${SERVER_PRIVATE_IP_1}:6335"

export ENV_CONTEXT="${NODE_URI@A} ${KILL_STORAGES@A} ${QDRANT_API_KEY@A} ${QDRANT_TAG@A}"



if [[ "$KILL_STORAGES" == "true" ]]
then
    export SERVER_NAME=qdrant-node-1
    RUN_SCRIPT="${SCRIPT_PATH}/local/drop-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
    export SERVER_NAME=qdrant-node-2
    RUN_SCRIPT="${SCRIPT_PATH}/local/drop-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
    export SERVER_NAME=qdrant-node-3
    RUN_SCRIPT="${SCRIPT_PATH}/local/drop-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
    export SERVER_NAME=qdrant-node-4
    RUN_SCRIPT="${SCRIPT_PATH}/local/drop-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
    export SERVER_NAME=qdrant-node-5
    RUN_SCRIPT="${SCRIPT_PATH}/local/drop-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
fi

# exit 0


export SERVER_NAME=qdrant-node-1

RUN_SCRIPT="${SCRIPT_PATH}/local/run-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
RUN_SCRIPT="${SCRIPT_PATH}/common/wait-qdrant-start.sh" bash -x $SCRIPT_PATH/run_remote.sh

export BOOTSTRAP_URL="http://${SERVER_PRIVATE_IP_1}:6335"


export ENV_CONTEXT="${BOOTSTRAP_URL@A} ${KILL_STORAGES@A} ${QDRANT_API_KEY@A} ${QDRANT_TAG@A}"


export SERVER_NAME=qdrant-node-2

RUN_SCRIPT="${SCRIPT_PATH}/local/run-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
RUN_SCRIPT="${SCRIPT_PATH}/common/wait-qdrant-start.sh" bash -x $SCRIPT_PATH/run_remote.sh

export SERVER_NAME=qdrant-node-3

RUN_SCRIPT="${SCRIPT_PATH}/local/run-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
RUN_SCRIPT="${SCRIPT_PATH}/common/wait-qdrant-start.sh" bash -x $SCRIPT_PATH/run_remote.sh


# Node 4 and 5 are read-only independent cluster

SERVER_PRIVATE_IP_4=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-4)
export NODE_URI="http://${SERVER_PRIVATE_IP_4}:6335"
export ENV_CONTEXT="${NODE_URI@A} ${KILL_STORAGES@A} ${QDRANT_API_KEY@A} ${QDRANT_TAG@A}"
export SERVER_NAME=qdrant-node-4

RUN_SCRIPT="${SCRIPT_PATH}/local/run-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
RUN_SCRIPT="${SCRIPT_PATH}/common/wait-qdrant-start.sh" bash -x $SCRIPT_PATH/run_remote.sh

export BOOTSTRAP_URL="http://${SERVER_PRIVATE_IP_4}:6335"
export ENV_CONTEXT="${BOOTSTRAP_URL@A} ${KILL_STORAGES@A} ${QDRANT_API_KEY@A} ${QDRANT_TAG@A}"

export SERVER_NAME=qdrant-node-5

RUN_SCRIPT="${SCRIPT_PATH}/local/run-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
RUN_SCRIPT="${SCRIPT_PATH}/common/wait-qdrant-start.sh" bash -x $SCRIPT_PATH/run_remote.sh




WRITE_PUBLIC_IP=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_public_ip.sh qdrant-node-1)
READ_PUBLIC_IP=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_public_ip.sh qdrant-node-5)

docker run --rm -it --network=host qdrant/bfb:dev ./bfb --uri "http://${WRITE_PUBLIC_IP}:6334" -b 50 -d 128 -n 30000 --max-id 999999999999 --indexing-threshold 2000 --replication-factor 1 -p 4 -t 1 --shards 3
docker run --rm -it --network=host qdrant/bfb:dev ./bfb --uri "http://${READ_PUBLIC_IP}:6334" -b 50 -d 128 -n 1 --replication-factor 2 -p 4 -t 1 --shards 3


# Start read stream

# docker run --rm -it --network=host -e QDRANT_API_KEY=${QDRANT_API_KEY} qdrant/bfb:dev ./bfb -d 128 --uri 'http://20.86.67.85:6334' --skip-create --skip-upload --skip-wait-index --search -n 500000 --timing-threshold 0.2 -p 4 -t 1 --indexed-only true

