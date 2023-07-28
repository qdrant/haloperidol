#!/usr/bin/env bash

set -euo pipefail

# This script tries to reach qdrant node for a given IP address until it is available

QDRANT_API_KEY="${QDRANT_API_KEY-}"

SERVER_ADDR="${1:-localhost:6333}"
TIMEOUT="${2:-60}"


START_TIMESTAMP="$(date +%s)"

echo "Waiting for qdrant node to start on $SERVER_ADDR"

until [[ "$(curl -s "http://$SERVER_ADDR" -H "api-key: $QDRANT_API_KEY" -w ''%{http_code}'' -o /dev/null)" == 200 ]]
do
    echo "Waiting for qdrant node to start on $SERVER_ADDR"
    sleep 2

    ELAPSED_TIME=$(("$(date +%s)" - START_TIMESTAMP))

    if (( ELAPSED_TIME > TIMEOUT ))
    then
        echo "Timeout reached"
        exit 1
    fi
done

echo "Qdrant node is started on $SERVER_ADDR"
