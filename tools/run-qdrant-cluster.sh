#!/bin/bash

set -e

# After machines are created, it should run qdrant cluster on them:

# - Run first node with --url and no --bootstrap
# - Run other nodes with --bootstrap parameter as a private ip of the first node

SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
CLOUD_NAME=${CLOUD_NAME:-"hetzner"}



SERVER_PRIVATE_IP_1=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-1)
# SERVER_PRIVATE_IP_2=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-2)
# SERVER_PRIVATE_IP_3=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-3)

KILL_STORAGES="false"

QDRANT_API_KEY=${QDRANT_API_KEY:-""}

# ToDo: start qdrant cluster on all nodes

NODE_URI="http://${SERVER_PRIVATE_IP_1}:6335"

export ENV_CONTEXT="${NODE_URI@A} ${KILL_STORAGES@A} ${QDRANT_API_KEY@A}"

export SERVER_NAME=qdrant-node-1

RUN_SCRIPT="${SCRIPT_PATH}/local/run-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
RUN_SCRIPT="${SCRIPT_PATH}/common/wait-qdrant-start.sh" bash -x $SCRIPT_PATH/run_remote.sh

BOOTSTRAP_URL="http://${SERVER_PRIVATE_IP_1}:6335"


export ENV_CONTEXT="${BOOTSTRAP_URL@A} ${KILL_STORAGES@A} ${QDRANT_API_KEY@A}"


export SERVER_NAME=qdrant-node-2

RUN_SCRIPT="${SCRIPT_PATH}/local/run-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
RUN_SCRIPT="${SCRIPT_PATH}/common/wait-qdrant-start.sh" bash -x $SCRIPT_PATH/run_remote.sh


export SERVER_NAME=qdrant-node-3

RUN_SCRIPT="${SCRIPT_PATH}/local/run-qdrant-node.sh" bash -x $SCRIPT_PATH/run_remote.sh
RUN_SCRIPT="${SCRIPT_PATH}/common/wait-qdrant-start.sh" bash -x $SCRIPT_PATH/run_remote.sh
