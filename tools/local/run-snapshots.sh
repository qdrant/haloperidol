#!/bin/bash

set -euo pipefail

set -x

QDRANT_API_KEY=${QDRANT_API_KEY:-""}

QDRANT_COLLECTION_NAME=${QDRANT_COLLECTION_NAME:-"benchmark"}

QDRANT_URIS=( ${QDRANT_HOSTS[@]/#/https://} )
QDRANT_URIS=( ${QDRANT_URIS[@]/%/:6333} )

function create_snapshot() {
    curl -s --fail-with-body -X POST -H "api-key: ${QDRANT_API_KEY}" "$1/collections/${QDRANT_COLLECTION_NAME}/snapshots"
}

function delete_snapshots() {
    curl -s --fail-with-body -X GET  -H "api-key: ${QDRANT_API_KEY}" "$1/collections/${QDRANT_COLLECTION_NAME}/snapshots" -s \
        | jq -r ".result[].name" \
        | xargs -I {} curl -X DELETE -H "api-key: ${QDRANT_API_KEY}" "$1/collections/${QDRANT_COLLECTION_NAME}/snapshots/{}"
}

function get_snapshot_count() {
    curl -X GET -H "api-key: ${QDRANT_API_KEY}" "$1/collections/${QDRANT_COLLECTION_NAME}/snapshots" -s \
    | jq -r ".result[].name" \
    | wc -l
}

function run_in_loop() {
    # Create snapshots
    for url in "${QDRANT_URIS[@]}"; do
        create_snapshot "$url" || true
        sleep 60
    done

    # Delete snapshots
    for url in "${QDRANT_URIS[@]}"; do
        delete_snapshots "$url" || true
        sleep 60
        snapshot_count=$(get_snapshot_count "$url" || "-1")
        if [ "$snapshot_count" -ne 0 ]; then
            echo "ERROR: Snapshot count is $snapshot_count (!= 0)"
            echo "::set-output name=failed::true"
        fi
    done
}

run_in_loop # > output-snapshots.log 2>&1 &
