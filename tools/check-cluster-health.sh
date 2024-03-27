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

echo "Checking data consistency"

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
is_data_consistent=false

consistency_attempts_remaining=3

while true; do
    first_node_points=""

    # Disable debug mode to make logs readable:
    # set +x
    for uri in "${QDRANT_URIS[@]}"; do
        points_response=$(curl -s --fail-with-body -X POST \
            --url "$uri/collections/benchmark/points" \
            --header "api-key: $QDRANT_API_KEY" \
            --header 'content-type: application/json' \
            --data "{\"ids\": $point_ids, \"with_vector\": true, \"with_payload\": true}")

        curl_exit_code=$?
        if [ "$curl_exit_code" -ne 0 ]; then
            echo "Failed to fetch points from $uri"
            is_data_consistent=false
            break
        fi

        fetched_points=$(echo "$points_response" | jq -rc '.result')

        # Check if data is consistent:
        if [ "$first_node_points" == "" ]; then
            # First node, no need to check:
            first_node_points="$fetched_points"
        elif [ "$fetched_points" == "$first_node_points" ]; then
            echo "Data is consistent with node-0 for $uri"
            is_data_consistent=true
        else
            echo "Data is inconsistent with node-0 for $uri"
            is_data_consistent=false
            break
        fi

    done
    # Enable debug mode again:
    # set -x

    if [ "$is_data_consistent" == "true" ]; then
        break
    else
        # is_data_consistent == false
        consistency_attempts_remaining=$((consistency_attempts_remaining - 1))
        if [ "$consistency_attempts_remaining" == "0" ]; then
            echo "Data consistency check failed despite 3 attempts"
            break
        else
            echo "Retrying data consistency check. Attempts remaining: $consistency_attempts_remaining / 3"
            continue
        fi
    fi
done


# Assume table:
# create table bfb_health (
# 	id SERIAL PRIMARY key,
# 	upload_operational BOOLEAN,
# 	search_operational BOOLEAN,
#   is_data_consistent BOOLEAN,
# 	measure_timestamp TIMESTAMP
# );

# TODO: Rename table as cluster_health
docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO bfb_health (upload_operational, search_operational, is_data_consistent, measure_timestamp) VALUES ($upload_operational, $search_operational, $is_data_consistent, '$NOW');"
