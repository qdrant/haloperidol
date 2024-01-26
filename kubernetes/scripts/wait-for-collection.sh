#!/bin/bash

set -uo pipefail

QDRANT_COLLECTION_NAME=${QDRANT_COLLECTION_NAME:-"benchmark"}

for i in {1..300}; do
    curl -SsL "$QDRANT_URL/collections" | grep "$QDRANT_COLLECTION_NAME"
    if [ $? -ne 0 ]; then
        echo "Waiting for collection '$QDRANT_COLLECTION_NAME' to exist... ($i/300)"
        sleep 2
    else
        echo "Collection '$QDRANT_COLLECTION_NAME' exists!"
        exit 0
    fi
done
echo "Timed out waiting for collection '$QDRANT_COLLECTION_NAME' to exist. Make sure bfb-upload is running successfully."
exit 1
