#!/bin/bash

set -euo pipefail

set -x

QDRANT_API_KEY=${QDRANT_API_KEY:-""}

QDRANT_COLLECTION_NAME=${QDRANT_COLLECTION_NAME:-"benchmark"}

QDRANT_URIS=( ${QDRANT_HOSTS[@]/#/https://} )
QDRANT_URIS=( ${QDRANT_URIS[@]/%/:6333} )

log_with_timestamp() {
    while IFS= read -r line; do
        echo "$(date --rfc-3339=seconds --utc) $line"
    done
}
# Redirect stdout (1) and stderr (2) to a log file
exec > >(log_with_timestamp >> /var/log/run-snapshots-cron.log) 2>&1

function create_snapshot() {
    snapshot_count=$(get_snapshot_count "$1")
    if [ "$snapshot_count" -gt 0 ]; then
        # This exists to avoid OOD errors
        echo "There are already $snapshot_count snapshots on $1, skipping..."
        return
    fi

    curl -s --fail-with-body -X POST -H "api-key: ${QDRANT_API_KEY}" "$1/collections/${QDRANT_COLLECTION_NAME}/snapshots"
}

function delete_snapshots() {
    curl -s --fail-with-body -X GET  -H "api-key: ${QDRANT_API_KEY}" "$1/collections/${QDRANT_COLLECTION_NAME}/snapshots" -s \
        | jq -r ".result[].name" \
        | xargs -I {} curl -X DELETE -H "api-key: ${QDRANT_API_KEY}" "$1/collections/${QDRANT_COLLECTION_NAME}/snapshots/{}"
}

function get_snapshot_count() {
    curl -s --fail-with-body -X GET -H "api-key: ${QDRANT_API_KEY}" "$1/collections/${QDRANT_COLLECTION_NAME}/snapshots" -s \
    | jq -r ".result[].name" \
    | wc -l
}

function run_in_loop() {
    # Create snapshots
    for url in "${QDRANT_URIS[@]}"; do
        create_snapshot "$url" || true
    done

    # Delete snapshots
    for url in "${QDRANT_URIS[@]}"; do
        delete_snapshots "$url" || true
        sleep 10
        snapshot_count=$(get_snapshot_count "$url" || "-1")
        if [ "$snapshot_count" -ne 0 ]; then
            echo "ERROR: Snapshot count is $snapshot_count (!= 0)"
            echo "::set-output name=failed::true"
        fi
    done
}

run_in_loop # > output-snapshots.log 2>&1 &
