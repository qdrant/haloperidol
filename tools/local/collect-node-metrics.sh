#!/bin/bash
PS4='ts=$(date "+%Y-%m-%dT%H:%M:%SZ") level=DEBUG line=$LINENO ' # Replace + with more meaningful debug trace logs
set -xuo pipefail

export QDRANT_API_KEY=${QDRANT_API_KEY:-""}
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

QDRANT_HOSTS_STR=${QDRANT_HOSTS_STR:-""}
if [ -n "$QDRANT_HOSTS_STR" ]; then
    IFS=',' read -r -a QDRANT_HOSTS <<< "$QDRANT_HOSTS_STR"
fi

# https is important here
QDRANT_URIS=( "${QDRANT_HOSTS[@]/#/https://}" )
QDRANT_URIS=( "${QDRANT_URIS[@]/%/:6333}" )

CHAOS_TESTING_VALUES=""
CHAOS_TESTING_SHARD_VALUES=""
CHAOS_TESTING_TRANSFER_VALUES=""

function handle_error() {
    local error_code=$?
    local error_line=$BASH_LINENO
    local error_command=$BASH_COMMAND
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S" --utc)
    echo "ts=$timestamp level=ERROR line=$error_line cmd=\"$error_command\" exit_code=$error_code"
}

function is_valid_json() {
  echo "$1" | jq -e . > /dev/null 2>&1
}

# Trap ERR signal and call handle_error function
trap 'handle_error' ERR

# function to insert to CHAOS_TESTING_VALUES:
function insert_to_chaos_testing_table {
    local uri=$1
    local version=$2
    local commit_id=$3
    local num_vectors=$4
    local num_snapshots=$5
    local measure_timestamp=$6

    if [ -n "$CHAOS_TESTING_VALUES" ]; then
        # If there are already values, add a comma
        CHAOS_TESTING_VALUES+=" ,"
    fi

    CHAOS_TESTING_VALUES+=" ('$uri', '$version', '$commit_id', $num_vectors, $num_snapshots, '$measure_timestamp')"
}

# function to insert to CHAOS_TESTING_SHARD_VALUES:
function insert_to_chaos_testing_shards_table {
    local uri=$1
    local peer_id=$2
    local shard_id=$3
    local points_count=$4
    local state=$5
    local measure_timestamp=$6

    if [ -n "$CHAOS_TESTING_SHARD_VALUES" ]; then
        # If there are already values, add a comma
        CHAOS_TESTING_SHARD_VALUES+=" ,"
    fi

    CHAOS_TESTING_SHARD_VALUES+=" ('$uri', $peer_id, $shard_id, $points_count, '$state', '$measure_timestamp')"
}

# function to insert to CHAOS_TESTING_TRANSFER_VALUES:
function insert_to_chaos_testing_transfer_table {
    local uri=$1
    local peer_id=$2
    local shard_id=$3
    local from_peer=$4
    local to_peer=$5
    local method=$6
    local comment=$7
    local progress_transfer=$8
    local total_to_transfer=$9
    local measure_timestamp=${10}

    if [ -n "$CHAOS_TESTING_TRANSFER_VALUES" ]; then
        # If there are already values, add a comma
        CHAOS_TESTING_TRANSFER_VALUES+=" ,"
    fi

    CHAOS_TESTING_TRANSFER_VALUES+=" ('$uri', $peer_id, $shard_id, $from_peer, $to_peer, '$method', '$comment', $progress_transfer, $total_to_transfer, '$measure_timestamp')"
}

for uri in "${QDRANT_URIS[@]}"; do
    echo "level=INFO msg=\"Checking node\" uri=$uri"

    root_api_response=$(curl -s --url "$uri/" --header "api-key: $QDRANT_API_KEY")

    if !(is_valid_json "$root_api_response"); then
        # Node is down
        insert_to_chaos_testing_table "$uri" "null" "null" 0 0 "$NOW"
        continue
    fi

    version=$(echo "$root_api_response" | jq -r '.version')

    commit_id=$(echo "$root_api_response" | jq -r '.commit')

    # This isn't stored in DB but is important for debugging
    cluster_response=$(curl -s $uri/cluster -H "api-key: $QDRANT_API_KEY")
    peer_id=$(echo "$cluster_response" | jq '.result.peer_id')
    peer_count=$(echo "$cluster_response" | jq '.result.peers | length')
    echo "level=INFO msg=\"Checked cluster\" peer_id=$peer_id uri=\"$uri\" cluster_response=\"$cluster_response\""
    if [ "$peer_count" -gt 4 ]; then
        echo "level=CRITICAL msg=\"Cluster has too many peers\" peer_count=$peer_count peer_id=$peer_id uri=\"$uri\" cluster_response=\"$cluster_response\""
    fi

    num_vectors=$(curl -s --request POST \
        --url "$uri/collections/benchmark/points/count" \
        --header "api-key: $QDRANT_API_KEY" \
        --header 'content-type: application/json' \
        --data '{"exact": true}' | jq -r '.result.count')

    # jq '... // 0' sets default value to 0
    # otherwise jq returns empty string which leads to invalid SQL
    num_snapshots=$(curl -s --request GET \
        --url "$uri/collections/benchmark/snapshots" \
        --header "api-key: $QDRANT_API_KEY" \
        --header 'content-type: application/json' \
        | jq -r '(.result[] | length) // 0')

    collection_cluster_response=$(curl -s --request GET \
        --url "$uri/collections/benchmark/cluster" \
        --header "api-key: $QDRANT_API_KEY" \
        --header 'content-type: application/json' \
        | jq -rc '.result'
    )
    insert_to_chaos_testing_table "$uri" "$version" "$commit_id" "$num_vectors" "$num_snapshots" "$NOW"

    peer_id=$(echo "$collection_cluster_response" | jq -r '.peer_id')
    local_shards=$(echo "$collection_cluster_response" | jq -rc '.local_shards[]') # [{"shard_id": 1, "points_count": .., "state": Active}, ...]

    # Note: Using echo "$local_shards" | while read -r shard; ... done creates a subshell which leads to global var
    # not being set.
    while read -r shard; do
        shard_id=$(echo "$shard" | jq -r '.shard_id')
        points_count=$(echo "$shard" | jq -r '.points_count')
        state=$(echo "$shard" | jq -r '.state')

        if [ "$shard_id" == "" ]; then
            echo "level=WARN msg=\"Shard not found\" peer_id=$peer_id uri=\"$uri\" "
        else
          insert_to_chaos_testing_shards_table "$uri" "$peer_id" "$shard_id" "$points_count" "$state" "$NOW"  
        fi

        if [ "$state" == "Dead" ]; then
            echo "level=WARN msg=\"Shard is dead\" shard_id=$shard_id peer_id=$peer_id uri=\"$uri\""
        fi
    done <<< "$local_shards"

    shard_transfers=$(echo "$collection_cluster_response" | jq -rc '.shard_transfers[]')
    while read -r transfer; do
        #  {
        #     "shard_id": 2,
        #     "from": 8023376283398464,
        #     "to": 364905008605704,
        #     "sync": true,
        #     "method": "stream_records",
        #     "comment": "Transferring records (8100/8149), started 1s ago, ETA: 0.00s"
        # }
        if [ "$transfer" == "" ]; then
            continue;
        fi

        shard_id=$(echo "$transfer" | jq -r '.shard_id')
        from_peer=$(echo "$transfer" | jq -r '.from')
        to_peer=$(echo "$transfer" | jq -r '.to')
        method=$(echo "$transfer" | jq -r '.method')

        comment=$(echo "$transfer" | jq -r '.comment')
        if [ "$comment" == "null" ]; then
            progress_transfer=0
            total_to_transfer=0
        else
            progress_transfer=$( echo "$comment" | grep -oP '(?<=\()\d+' )
            total_to_transfer=$( echo "$comment" | grep -oP '(?<=/)\d+(?=\))' )
        fi

        insert_to_chaos_testing_transfer_table "$uri" "$peer_id" "$shard_id" "$from_peer" "$to_peer" "$method" "$comment" "$progress_transfer" "$total_to_transfer" "$NOW"
    done <<< "$shard_transfers"
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

docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO chaos_testing (url, version, commit, num_vectors, num_snapshots, measure_timestamp) VALUES $CHAOS_TESTING_VALUES;"

# Assume table:
# create table chaos_testing_shards (
#   id SERIAL PRIMARY key,
#   url VARCHAR(255),
#   peer_id bigint,
#   shard_id INT,
#   points_count INT,
#   state VARCHAR(255),
#   measure_timestamp TIMESTAMP
# );

if [ -n "$CHAOS_TESTING_SHARD_VALUES" ]; then
    docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO chaos_testing_shards (url, peer_id, shard_id, points_count, state, measure_timestamp) VALUES $CHAOS_TESTING_SHARD_VALUES;"
else
    echo "level=ERROR msg=\"No shards found\""
fi

# Assume table:
# create table chaos_testing_transfers (
#   id SERIAL PRIMARY key,
#   url VARCHAR(255),
#   peer_id bigint,
#   shard_id INT,
#   from_peer bigint,
#   to_peer bigint,
#   method VARCHAR(255),
#   comment VARCHAR(255),
#   progress_transfer INT,
#   total_to_transfer INT,
#   measure_timestamp TIMESTAMP
# );

if [ -n "$CHAOS_TESTING_TRANSFER_VALUES" ]; then
    docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO chaos_testing_transfers (url, peer_id, shard_id, from_peer, to_peer, method, comment, progress_transfer, total_to_transfer, measure_timestamp) VALUES $CHAOS_TESTING_TRANSFER_VALUES;"
else
    echo "level=INFO msg=\"No transfers found\""
fi
