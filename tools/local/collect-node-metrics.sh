#!/bin/bash
set -euo pipefail

export QDRANT_API_KEY=${QDRANT_API_KEY:-""}
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# https is important here
QDRANT_URIS=( ${QDRANT_HOSTS[@]/#/https://} )
QDRANT_URIS=( ${QDRANT_URIS[@]/%/:6333} )

PSQL_VALUES=""

# function to insert to PSQL_VALUES:
function insert_to_psql_values {
    local uri=$1
    local version=$2
    local commit_id=$3
    local num_vectors=$4
    local num_snapshots=$5
    local is_data_consistent=$6
    local measure_timestamp=$7

    if [ -n "$PSQL_VALUES" ]; then
        # If there are already values, add a comma
        PSQL_VALUES+=" ,"
    fi

    PSQL_VALUES+=" ('$uri', '$version', '$commit_id', $num_vectors, $num_snapshots, $is_data_consistent, '$measure_timestamp')"
}

# generate 100 random numbers between 0 and 20K and convert into JSON array:
point_ids=$(shuf -i 0-20000 -n 100 | jq -sc .)
is_data_consistent=true
last_fetched_points=""

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


    consistency_attempts_remaining=3

    while true; do
        consistency_attempts_remaining=$((consistency_attempts_remaining - 1))

        if [ "$consistency_attempts_remaining" == "0" ]; then
            is_data_consistent=false
            break
        fi

        fetched_points=$(curl --request POST \
            --url "$uri/collections/benchmark/points" \
            --header "api-key: $QDRANT_API_KEY" \
            --header 'content-type: application/json' \
            --data "{\"ids\": $point_ids, \"with_vector\": true, \"with_payload\": true}" | jq -r '.result')

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
    done

    insert_to_psql_values "$uri" "$version" "$commit_id" "$num_vectors" "$num_snapshots" "$is_data_consistent" "$NOW"

    sleep 1
done

# Read search results from json file and upload it to postgres
# Assume table:
# create table chaos_testing (
# 	id SERIAL PRIMARY key,
#   url VARCHAR(255),
# 	version VARCHAR(255),
#   commit CHAR(40),
#   num_vectors INT,
#   num_snapshots INT,
#   is_data_consistent BOOLEAN,
# 	measure_timestamp TIMESTAMP
# );


docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO chaos_testing (url, version, commit, num_vectors, num_snapshots, is_data_consistent, measure_timestamp) VALUES $PSQL_VALUES;"
