#!/bin/bash

set -euo pipefail

QDRANT_COLLECTION_NAME=${QDRANT_COLLECTION_NAME:-"benchmark"}

QDRANT_URL=${QDRANT_URL:-"http://localhost:6333"}

function create_and_delete_snapshot() {
    curl -X POST "${QDRANT_URL}/collections/${QDRANT_COLLECTION_NAME}/snapshots"

    curl -X GET  "${QDRANT_URL}/collections/${QDRANT_COLLECTION_NAME}/snapshots" -s \
        | jq -r .result[].name \
        | xargs -I {} curl -X DELETE "${QDRANT_URL}/collections/${QDRANT_COLLECTION_NAME}/snapshots/{}"
}


function run_in_loop() {
    for i in {1..10}; do
        create_and_delete_snapshot || true
        sleep 60
    done
}


run_in_loop
