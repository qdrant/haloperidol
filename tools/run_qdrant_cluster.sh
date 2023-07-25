#!/bin/bash



# After machines are created, it should run qdrant cluster on them:

# - Run first node with --url and no --bootstrap
# - Run other nodes with --bootstrap parameter as a private ip of the first node

SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
CLOUD_NAME=${CLOUD_NAME:-"hetzner"}


SERVER_PRIVATE_IP_1=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-1)
SERVER_PRIVATE_IP_2=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-2)
SERVER_PRIVATE_IP_3=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_private_ip.sh qdrant-node-3)


# ToDo: start qdrant cluster on all nodes