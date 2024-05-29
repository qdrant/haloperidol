#!/bin/bash

set -uo pipefail

set -x

QDRANT_API_KEY=${QDRANT_API_KEY:-""}

QDRANT_COLLECTION_NAME=${QDRANT_COLLECTION_NAME:-"benchmark"}

QDRANT_URIS=( ${QDRANT_HOSTS[@]/#/https://} )
QDRANT_URIS=( ${QDRANT_URIS[@]/%/:6333} )

log_with_timestamp() {
    while IFS= read -r line; do
        echo "timestamp=$(date --rfc-3339=seconds --utc) $line"
    done
}
# Redirect stdout (1) and stderr (2) to a log file
exec > >(log_with_timestamp >> /var/log/run-snapshots-cron.log) 2>&1

function create_snapshot() {
    snapshot_count=$(get_snapshot_count "$1")
    if [ "$snapshot_count" -gt 0 ]; then
        # This exists to avoid OOD errors
        echo "operation=create_snapshot action=skip msg=\"already $snapshot_count snapshots\" url=$1"
        return
    fi

    snapshot=$(curl -s --fail-with-body -X POST -H "api-key: ${QDRANT_API_KEY}" "$1/collections/${QDRANT_COLLECTION_NAME}/snapshots" | jq -r ".result.name")
    echo "operation=create_snapshot action=create msg=\"created snapshot $snapshot\" url=$1"
}

function delete_snapshots() {
    snapshot_names=$(curl -s --fail-with-body -X GET  -H "api-key: ${QDRANT_API_KEY}" "$1/collections/${QDRANT_COLLECTION_NAME}/snapshots" -s \
        | jq -r ".result[].name")
    echo "operation=delete_snapshots action=fetch_snapshots snapshots=\"$snapshot_names\" url=$1"
    echo "$snapshot_names" | xargs -I {} curl -s --fail-with-body -X DELETE -H "api-key: ${QDRANT_API_KEY}" "$1/collections/${QDRANT_COLLECTION_NAME}/snapshots/{}"
    echo "operation=delete_snapshots action=delete snapshots=$snapshot_names url=$1"
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

while true; do
  echo "==================="
  echo "Creating snapshot..."

  run_in_loop # > output-snapshots.log 2>&1 &
  # generate a time (seconds) between 30mins and 1 hour:
  delay=$((RANDOM % 1800 + 30 * 60))
  echo "Sleeping for ${delay}s"
  sleep $delay # 1hr
done
