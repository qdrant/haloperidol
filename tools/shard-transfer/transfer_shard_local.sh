#!/bin/bash


WRITE_SERVER_IP=${WRITE_SERVER_IP:-""}
READ_SERVER_IP=${READ_SERVER_IP:-""}
SHARD_ID=${SHARD_ID:-""}

COLLECTION_NAME=${COLLECTION_NAME:-"benchmark"}

if [[ "$WRITE_SERVER_IP" == "" ]]
then
    echo "WRITE_SERVER_IP is not set"
    exit 1
fi

if [[ "$READ_SERVER_IP" == "" ]]
then
    echo "READ_SERVER_IP is not set"
    exit 1
fi


if [[ "$SHARD_ID" == "" ]]
then
    # Get shard info
    SHARD_ID=$(curl -X GET -H "Content-Type: application/json" "http://${WRITE_SERVER_IP}:6333/collections/${COLLECTION_NAME}/cluster" | jq -r '.result.local_shards[0].shard_id')
fi


SNAPSHOT_NAME=$(curl -X POST -H "Content-Type: application/json" -d '{}' "http://${WRITE_SERVER_IP}:6333/collections/${COLLECTION_NAME}/shards/${SHARD_ID}/snapshots" | jq -r '.result.name' )


SNAPSHOT_URL="http://${WRITE_SERVER_IP}:6333/collections/${COLLECTION_NAME}/shards/${SHARD_ID}/snapshots/${SNAPSHOT_NAME}"


# recover snapshot on read server

curl -X PUT -H "Content-Type: application/json" -d " \
    {\"location\": \"${SNAPSHOT_URL}\", \"priority\": \"local_only\"}" \
    "http://${READ_SERVER_IP}:6333/collections/${COLLECTION_NAME}/shards/${SHARD_ID}/snapshots/recover" | jq