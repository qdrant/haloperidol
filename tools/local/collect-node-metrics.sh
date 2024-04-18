#!/bin/bash
set -euo pipefail

export QDRANT_API_KEY=${QDRANT_API_KEY:-""}
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

QDRANT_HOSTS=${QDRANT_HOSTS:-""}
if [ -z "$QDRANT_HOSTS" ]; then
    # QDRANT_HOSTS=( $QDRANT_HOSTS_STR )
    read -ar QDRANT_HOSTS <<< "$QDRANT_HOSTS_STR"
fi
# https is important here
QDRANT_URIS=( "${QDRANT_HOSTS[@]/#/https://}" )
QDRANT_URIS=( "${QDRANT_URIS[@]/%/:6333}" )

PSQL_VALUES=""

echo "Cluster URL:" "$QDRANT_CLUSTER_URL"
echo URIs: "${QDRANT_URIS[@]}"

# function to insert to PSQL_VALUES:
function insert_to_psql_values {
    local uri=$1
    local version=$2
    local commit_id=$3
    local num_vectors=$4
    local num_snapshots=$5
    local measure_timestamp=$6

    if [ -n "$PSQL_VALUES" ]; then
        # If there are already values, add a comma
        PSQL_VALUES+=" ,"
    fi

    PSQL_VALUES+=" ('$uri', '$version', '$commit_id', $num_vectors, $num_snapshots, '$measure_timestamp')"
}

for uri in "${QDRANT_URIS[@]}"; do
    echo "$uri"

    root_api_response=$(curl --url "$uri/" --header "api-key: $QDRANT_API_KEY")

    if ! (echo "$root_api_response" | jq -e '.'); then
        # Node is down
        insert_to_psql_values "$uri" "null" "null" 0 0 "$NOW"
        continue
    fi

    version=$(echo "$root_api_response" | jq -r '.version')

    commit_id=$(echo "$root_api_response" | jq -r '.commit')

    num_vectors=$(curl --request POST \
        --url "$uri/collections/benchmark/points/count" \
        --header "api-key: $QDRANT_API_KEY" \
        --header 'content-type: application/json' \
        --data '{"exact": true}' | jq -r '.result.count')

    # jq '... // 0' sets default value to 0
    # otherwise jq returns empty string which leads to invalid SQL
    num_snapshots=$(curl --request GET \
        --url "$uri/collections/benchmark/snapshots" \
        --header "api-key: $QDRANT_API_KEY" \
        --header 'content-type: application/json' \
        | jq -r '(.result[] | length) // 0')

    insert_to_psql_values "$uri" "$version" "$commit_id" "$num_vectors" "$num_snapshots" "$NOW"
done

# Read search results from json file and upload it to postgres
# Assume table:
# create table chaos_testing (
#   id SERIAL PRIMARY key,
#   url VARCHAR(255),
#   version VARCHAR(255),
#   commit CHAR(40),
#   num_vectors INT,
#   num_snapshots INT,
#   measure_timestamp TIMESTAMP
# );


docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO chaos_testing (url, version, commit, num_vectors, num_snapshots, measure_timestamp) VALUES $PSQL_VALUES;"
