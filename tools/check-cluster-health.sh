#!/usr/bin/env bash

set -uo pipefail
set -x

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

# generate 100 random numbers between 0 and 200K and convert into JSON array:
num_points_to_check=100
point_ids=$(shuf -i 0-200000 -n "$num_points_to_check" | jq -sc .)

is_data_consistent=false
first_node_points=""

consistency_attempts_remaining=3

function calculate_inconsistent_points() {
    source_points=$1
    target_points=$2

    inconsistent_points=()
    source_points_length=$(echo "$source_points" | jq '. | length')

    for idx in $(seq 0 "$source_points_length"); do
        source_vector=$(echo "$source_points" | jq -r ".[$idx] | .vector")
        target_vector=$(echo "$target_points" | jq -r ".[$idx] | .vector")

        if [ "$source_vector" != "$target_vector" ]; then
            point_id=$(echo "$source_points" | jq -r ".[$idx] | .id")
            inconsistent_points+=("$point_id")
        fi
    done

    echo "${inconsistent_points[@]}"
}

while true; do
    # Disable debug mode to make logs readable. Vectors in response will bloat the log.
    set +x
    num_nodes=$(curl -s --fail-with-body -X GET \
        --url "https://${QDRANT_CLUSTER_URL}:6333/cluster" \
        --header "api-key: $QDRANT_API_KEY" \
        | jq -r '.result.peers | length')
    echo "Number of nodes: $num_nodes"
    QDRANT_HOSTS=()
    for IDX in $(seq 0 $((num_nodes - 1))); do
        QDRANT_HOSTS+=("node-${IDX}-${QDRANT_CLUSTER_URL}")
    done

    # https is important here
    QDRANT_URIS=( "${QDRANT_HOSTS[@]/#/https://}" )
    QDRANT_URIS=( "${QDRANT_URIS[@]/%/:6333}" )

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

        # Sort by .result[].id
        fetched_points=$(echo "$points_response" | jq -rc '.result | sort_by(.id)')
        fetched_points_count=$(echo "$fetched_points" | jq 'length')

        echo "Got $fetched_points_count points from $uri"

        # Check if data is consistent:
        if [ "$first_node_points" == "" ]; then
            # First node, no need to check:
            first_node_points="$fetched_points"
        elif [ "$fetched_points" == "$first_node_points" ]; then
            echo "$uri data is consistent with node-0"
            is_data_consistent=true
        else
            inconsistent_points=()
            array_response=$(calculate_inconsistent_points "$first_node_points" "$fetched_points")
            read -ra inconsistent_points <<< "$array_response"

            # inconsistent_points is a bash array
            echo "$uri data is inconsistent with node-0 by ${#inconsistent_points[@]} points"
            echo "Inconsistent point IDs:" "${inconsistent_points[@]}"
            is_data_consistent=false
            break
        fi

    done
    # Enable debug mode again:
    set -x

    consistency_attempts_remaining=$((consistency_attempts_remaining - 1))

    if [ "$is_data_consistent" == "true" ]; then
        echo "Data consistency check succeeded with $((3 - consistency_attempts_remaining)) attempt(s)"
        break
    else
        # is_data_consistent == false
        if [ "$consistency_attempts_remaining" == "0" ]; then
            echo "Data consistency check failed despite 3 attempts"
            break
        else
            echo "Retrying data consistency check. Attempts remaining: $consistency_attempts_remaining / 3"
            sleep 5 # node might be unavailable which caused curl to fail. give k8s some time to heal
            first_node_points=""
            continue
        fi
    fi
done


# Assume table:
# create table bfb_health (
# 	id SERIAL PRIMARY key,
# 	upload_operational BOOLEAN,
# 	search_operational BOOLEAN,
# 	is_data_consistent BOOLEAN,
# 	measure_timestamp TIMESTAMP
# );

# TODO: Rename table as cluster_health
docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO bfb_health (upload_operational, search_operational, is_data_consistent, measure_timestamp) VALUES ($upload_operational, $search_operational, $is_data_consistent, '$NOW');"
