#!/bin/bash
set -e

export QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}
export QDRANT_API_KEY=${QDRANT_API_KEY:-""}

# https is important here
QDRANT_URIS=( ${QDRANT_HOSTS[@]/#/https://} )
QDRANT_URIS=( ${QDRANT_URIS[@]/%/:6333} )

PSQL_VALUES=""

for uri in "${QDRANT_URIS[@]}"; do
    echo "$uri"

    root_api_response=$(curl --url "$uri/" --header "api-key: $QDRANT_API_KEY")

    version=$(echo "$root_api_response" | jq -r '.version')
    # if crashes or version null, then skip
    if [ -z "$version" ] || [ "$version" == "null" ]; then
        continue
    fi

    commit_id=$(echo "$root_api_response" | jq -r '.commit')
    # if crashes or commit id null, then skip
    # FIXME: Uncomment it once we start deploying 'dev' releases
    # if [ -z "$commit_id" ] || [ "$commit_id" == "null" ]; then
    #     continue
    # fi

    num_vectors=$(curl --request POST \
        --url "$uri/collections/benchmark/points/count" \
        --header "api-key: $QDRANT_API_KEY" \
        --header 'content-type: application/json' \
        --data '{"exact": true}' | jq -r '.result.count')
    if [ -z "$num_vectors" ] || [ "$num_vectors" == "null" ]; then
        continue
    fi

    if [ -n "$PSQL_VALUES" ]; then
        # If there are already values, add a comma
        PSQL_VALUES+=" ,"
    fi

    PSQL_VALUES+=" ('$uri', '$version', '$commit_id', $num_vectors, '$(date -u +"%Y-%m-%dT%H:%M:%SZ")')"

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
# 	measure_timestamp TIMESTAMP
# );


if [ -z "$PSQL_VALUES" ]; then
    echo "No values to insert"
    exit 0
fi

docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO chaos_testing (url, version, commit, num_vectors, measure_timestamp) VALUES $PSQL_VALUES;"
