#!/bin/bash


# This script should create N virtual machies with docker installed and configured
# Plus one virtual machine with docker for generating load

# Path to current script

SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
CLOUD_NAME=${CLOUD_NAME:-"hetzner"}


export SERVER_TYPE=${SERVER_TYPE:-cx11}

SERVER_NAME=qdrant-node-1 bash -x $SCRIPT_PATH/clouds/$CLOUD_NAME/create_and_install.sh
SERVER_NAME=qdrant-node-2 bash -x $SCRIPT_PATH/clouds/$CLOUD_NAME/create_and_install.sh
SERVER_NAME=qdrant-node-3 bash -x $SCRIPT_PATH/clouds/$CLOUD_NAME/create_and_install.sh
SERVER_NAME=qdrant-manager bash -x $SCRIPT_PATH/clouds/$CLOUD_NAME/create_and_install.sh

