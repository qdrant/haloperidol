#!/bin/bash

set -e
set -x

# path relative to the script
SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
SSH_USER="azureuser"

# Manually create server in Azure Cloud and pass IPs:
PUBLIC_SERVER_IP=$1
PUBLIC_CLIENT_IP=$2
PRIVATE_SERVER_IP=$3
DATASET=$4

# if either of the above vars are not set, throw error with var name:
if [ -z "$PUBLIC_SERVER_IP" ] || [ -z "$PUBLIC_CLIENT_IP" ] || [ -z "$PRIVATE_SERVER_IP" ]; then
    echo "ERROR: one or more of the following variables are not set: PUBLIC_SERVER_IP, PUBLIC_CLIENT_IP, PRIVATE_SERVER_IP"
    exit 1
fi

if [ -z "$DATASET" ]; then
    echo "ERROR: DATASET is not set"
    exit 1
fi

# Copy server and client setup scripts:
scp "${SCRIPTPATH}/setup_server.sh" "${SSH_USER}@${PUBLIC_SERVER_IP}:/home/${SSH_USER}/setup_server.sh"
scp "${SCRIPTPATH}/setup_client.sh" "${SSH_USER}@${PUBLIC_CLIENT_IP}:/home/${SSH_USER}/setup_client.sh"

# run the script with different vector dbs:
vectordbs=("qdrant" "weaviate" "milvus")

for vdb in "${vectordbs[@]}"; do
    echo $vdb
    ssh "${SSH_USER}@${PUBLIC_SERVER_IP}" "sudo bash /home/${SSH_USER}/setup_server.sh ${vdb}"
    ssh "${SSH_USER}@${PUBLIC_CLIENT_IP}" "bash /home/${SSH_USER}/setup_client.sh ${vdb} ${DATASET} ${PRIVATE_SERVER_IP}"
done
