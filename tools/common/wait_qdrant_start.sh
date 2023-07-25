#!/bin/bash


set -e

# This script tries to reach qdrant node for a given IP address until it is available



TIMEOUT=${TIMEOUT:-"60"}
SERVER_IP=${SERVER_IP:-"localhost"}


START_TIMESTAMP=$(date +%s)

echo "Waiting for qdrant node to start on $SERVER_IP"

until [[ "$(curl -s -o /dev/null -w ''%{http_code}'' http://${SERVER_IP}:6333 )" == "200" ]]; do
    echo "Waiting for qdrant node to start on $SERVER_IP"
    sleep 2

    ELAPSED_TIME=$(($(date +%s) - $START_TIMESTAMP))

    if [[ "$ELAPSED_TIME" -gt "$TIMEOUT" ]]; then
        echo "Timeout reached"
        exit 1
    fi
done


echo "Qdrant node is started on $SERVER_IP"


