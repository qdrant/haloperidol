#!/bin/bash


set -e


SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ROOT_PATH=$(dirname $SCRIPT_PATH)
SCRIPT_PATH="${ROOT_PATH}"

export CLOUD_NAME=${CLOUD_NAME:-"custom"}


SERVER_PRIVATE_IP_1=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-1)
SERVER_PRIVATE_IP_2=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-2)
SERVER_PRIVATE_IP_3=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-3)
SERVER_PRIVATE_IP_4=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-4)
SERVER_PRIVATE_IP_5=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-5)



function transfer_shard() {
    export WRITE_SERVER_IP=$1


    export READ_SERVER_IP=${SERVER_PRIVATE_IP_4}
    export SERVER_NAME=qdrant-node-5
    export ENV_CONTEXT="${WRITE_SERVER_IP@A} ${READ_SERVER_IP@A}"
    RUN_SCRIPT="${SCRIPT_PATH}/shard-transfer/transfer_shard_local.sh" bash -x $SCRIPT_PATH/run_remote.sh


    export READ_SERVER_IP=${SERVER_PRIVATE_IP_5}
    export SERVER_NAME=qdrant-node-4
    export ENV_CONTEXT="${WRITE_SERVER_IP@A} ${READ_SERVER_IP@A}"
    RUN_SCRIPT="${SCRIPT_PATH}/shard-transfer/transfer_shard_local.sh" bash -x $SCRIPT_PATH/run_remote.sh
}


transfer_shard ${SERVER_PRIVATE_IP_1}
transfer_shard ${SERVER_PRIVATE_IP_2}
transfer_shard ${SERVER_PRIVATE_IP_3}


