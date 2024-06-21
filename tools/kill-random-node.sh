#!/bin/bash


set -e

# Select random node, ssh to it and restart qdrant with docker restart

SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
CLOUD_NAME=${CLOUD_NAME:-"hetzner"}


SERVER_IDX=$(( ( RANDOM % 3 )  + 1 ))

SERVER_NAME="qdrant-node-${SERVER_IDX}"


RUN_SCRIPT="${SCRIPT_PATH}/local/restart-qdrant-node.sh" SERVER_NAME=${SERVER_NAME} bash -x "$SCRIPT_PATH/run_remote.sh"


