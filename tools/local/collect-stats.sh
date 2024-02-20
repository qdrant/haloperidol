#!/bin/bash
set -e

export QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}
declare QDRANT_HOSTS=()
export QDRANT_API_KEY=${QDRANT_API_KEY:-""}

# Need https for chaos-testing deployments
QDRANT_URIS=( ${QDRANT_HOSTS[@]/#/https://} )
QDRANT_URIS=( ${QDRANT_URIS[@]/%/:6333} )

PSQL_QUERY="INSERT INTO chaos_testing (url, version, commit, num_vectors, measure_timestamp) VALUES "

for uri in "${QDRANT_URIS[@]}"; do
    echo "$uri"

    root_api_response=$(curl --url "$uri/")

    version=$(echo "$root_api_response" | jq '.version')
    # if crashes or version null, then skip
    if [ -z "$version" ] || [ "$version" == "null" ]; then
        continue
    fi

    commit_id=$(echo "$root_api_response" | jq '.commit')
    # if crashes or commit id null, then skip
    if [ -z "$commit_id" ] || [ "$commit_id" == "null" ]; then
        continue
    fi

    num_vectors=$(curl --request POST \
        --url "$uri/collections/benchmark/points/count" \
        --header "api-key: $QDRANT_API_KEY" \
        --header 'content-type: application/json' \
        --data '{"exact": true}' | jq '.result.count')
    if [ -z "$num_vectors" ] || [ "$num_vectors" == "null" ]; then
        continue
    fi

    PSQL_QUERY+="($uri, $version, $commit_id, $num_vectors, '$(date -u +"%Y-%m-%dT%H:%M:%SZ")')"
done

# Read search results from json file and upload it to postgres
# Assume table:
# create table chaos_testing (
# 	id SERIAL PRIMARY key,
#   url VARCHAR(255),
# 	version VARCHAR(255),
#   commit CHAR(40),
#   num_vectors INT,
# 	measure_timestamp TIMESTAMP
# );

docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "$PSQL_QUERY;"
