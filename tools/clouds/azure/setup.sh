#!/bin/bash

set -e

# path relative to the script
SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
SSH_USER="azureuser"

# Manually create server in Azure Cloud and pass IPs:
PUBLIC_SERVER_IP=$1
PUBLIC_CLIENT_IP=$2
PRIVATE_SERVER_IP=$3
DATASET=$4

scp "${SCRIPTPATH}/setup_server.sh" "${SSH_USER}@${PUBLIC_SERVER_IP}:/home/${SSH_USER}/setup_server.sh"

# run the script with different vector dbs: qdrant, qdrant-rps, weaviate, and milvus
vectordbs=("qdrant" "qdrant-rps" "weaviate" "milvus")

for vdb in "${vectordbs[@]}"
    ssh "${SSH_USER}@${PUBLIC_SERVER_IP}" "bash /home/${SSH_USER}/setup_server.sh ${vdb}"
    ssh "${SSH_USER}@${PUBLIC_CLIENT_IP}" "bash /home/${SSH_USER}/setup_client.sh ${vdb} ${DATASET} ${PRIVATE_SERVER_IP}"
done
