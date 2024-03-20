#!/usr/bin/env bash

set -uo pipefail

function self {
	realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
	return "$?"
}

declare SELF="$(self)"
declare ROOT="$(dirname "$SELF")"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

RUN_SCRIPT="$ROOT/local/check-docker-exit-code.sh"

CONTAINER_NAME=bfb-upload

RUN_SCRIPT=$RUN_SCRIPT \
	ENV_CONTEXT="${CONTAINER_NAME@A}" \
	SERVER_NAME=qdrant-manager \
	bash -x "$ROOT/run_remote.sh"

# check exit code:
if [ $? -ne 0 ]; then
	upload_operational=false
else
	upload_operational=true
fi

CONTAINER_NAME=bfb-search

RUN_SCRIPT=$RUN_SCRIPT \
	ENV_CONTEXT="${CONTAINER_NAME@A}" \
	SERVER_NAME=qdrant-manager \
	bash -x "$ROOT/run_remote.sh"

# check exit code:
if [ $? -ne 0 ]; then
	search_operational=false
else
	search_operational=true
fi

echo "upload_operational: $upload_operational, search_operational: $search_operational, measure_timestamp: $NOW"

# Data consistency check:

QDRANT_API_KEY=${QDRANT_API_KEY:-""}
QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}

for IDX in {0..4}; do
    QDRANT_HOSTS+=("node-${IDX}-${QDRANT_CLUSTER_URL}")
done

# https is important here
QDRANT_URIS=( "${QDRANT_HOSTS[@]/#/https://}" )
QDRANT_URIS=( "${QDRANT_URIS[@]/%/:6333}" )

# generate 100 random numbers between 0 and 20K and convert into JSON array:
point_ids=$(shuf -i 0-20000 -n 100 | jq -sc .)
is_data_consistent=true
last_fetched_points=""

for uri in "${QDRANT_URIS[@]}"; do
	# Disable debug mode to make logs readable:
	consistency_attempts_remaining=3

    while true; do
        consistency_attempts_remaining=$((consistency_attempts_remaining - 1))

        if [ "$consistency_attempts_remaining" == "0" ]; then
            echo "Data consistency check failed for $uri"
            is_data_consistent=false
            break
        fi

        # Disable debug mode to make logs readable:
        set +x
        fetched_points=$(curl --request POST \
            --url "$uri/collections/benchmark/points" \
            --header "api-key: $QDRANT_API_KEY" \
            --header 'content-type: application/json' \
            --data "{\"ids\": $point_ids, \"with_vector\": true, \"with_payload\": true}" | jq -rc '.result')

        # Check if data is consistent:
        # First node, no need to check:
        if [ "$last_fetched_points" == "" ]; then
            last_fetched_points="$fetched_points"
            continue
        fi

        if [ "$fetched_points" == "$last_fetched_points" ]; then
            echo "Data is consistent for $uri"
            break
        else
            echo "Data is inconsistent for $uri. Attempts remaining: $consistency_attempts_remaining / 3"
            sleep 1
        fi
        # Enable debug mode again:
        set -x
    done
done

# TODO: Rename to cluster_health
# Assume table:
# create table bfb_health (
# 	id SERIAL PRIMARY key,
# 	upload_operational BOOLEAN,
# 	search_operational BOOLEAN,
#   is_data_consistent BOOLEAN,
# 	measure_timestamp TIMESTAMP
# );

docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO bfb_health (upload_operational, search_operational, is_data_consistent, measure_timestamp) VALUES ($upload_operational, $search_operational, $is_data_consistent, '$NOW');"
