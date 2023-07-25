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


KILL_STORAGES="true"

# ToDo: start qdrant cluster on all nodes

NODE_URI="http://${SERVER_PRIVATE_IP_1}:6335"

RUN_SCRIPT="${SCRIPT_PATH}/local/run-qdrant-node.sh" \
    SERVER_NAME=qdrant-node-1 \
    ENV_CONTEXT="${NODE_URI@A} ${KILL_STORAGES@A}" \
    bash -x $SCRIPT_PATH/run_remote.sh

sleep 5

BOOTSTRAP_URL="http://${SERVER_PRIVATE_IP_1}:6335"


RUN_SCRIPT="${SCRIPT_PATH}/local/run-qdrant-node.sh" \
    SERVER_NAME=qdrant-node-2 \
    ENV_CONTEXT="${BOOTSTRAP_URL@A} ${KILL_STORAGES@A}" \
    bash -x $SCRIPT_PATH/run_remote.sh


RUN_SCRIPT="${SCRIPT_PATH}/local/run-qdrant-node.sh" \
    SERVER_NAME=qdrant-node-3 \
    ENV_CONTEXT="${BOOTSTRAP_URL@A} ${KILL_STORAGES@A}" \
    bash -x $SCRIPT_PATH/run_remote.sh
