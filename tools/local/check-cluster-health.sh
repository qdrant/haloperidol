#!/bin/bash

# PS4='ts=$(date -u "+%Y-%m-%dT%H:%M:%SZ") level=trace line=$LINENO '; set -x; # too verbose; disabled
# trap 'echo "ts=$(date -u "+%Y-%m-%dT%H:%M:%SZ") level=trace line=$LINENO cmd=\"$BASH_COMMAND\""' DEBUG # less verbose; but still noisy; disabled
source "tools/local/logging.sh"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

QC_NAME=${QC_NAME:-"qdrant-chaos-testing"}
QDRANT_PYTHON_CLIENT_VERSION=${QDRANT_PYTHON_CLIENT_VERSION:-"1.12.1"}

if [ "$QC_NAME" == "qdrant-chaos-testing" ]; then
    UPLOAD_CONTAINER_NAME="bfb-upload"
    SEARCH_CONTAINER_NAME="bfb-search"
    POSTGRES_CLIENT_CONTAINER_NAME="postgres-client"
elif [ "$QC_NAME" == "qdrant-chaos-testing-debug" ]; then
    UPLOAD_CONTAINER_NAME="bfb-upload-debug"
    SEARCH_CONTAINER_NAME="bfb-search-debug"
    POSTGRES_CLIENT_CONTAINER_NAME="postgres-client-debug"
elif [ "$QC_NAME" == "qdrant-chaos-testing-three" ]; then
    UPLOAD_CONTAINER_NAME="bfb-upload-three"
    SEARCH_CONTAINER_NAME="bfb-search-three"
    POSTGRES_CLIENT_CONTAINER_NAME="postgres-client-three"
else
    log error "Unexpected QdrantCluster $QC_NAME"
    exit 1
fi

CONTAINER_NAME=$UPLOAD_CONTAINER_NAME tools/local/check-docker-exit-code.sh
exit_code=$?
upload_operational=$([ $exit_code -eq 0 ] && echo true || echo false)

CONTAINER_NAME=$SEARCH_CONTAINER_NAME tools/local/check-docker-exit-code.sh
exit_code=$?
search_operational=$([ $exit_code -eq 0 ] && echo true || echo false)

is_data_consistent=true
pids=()

log debug "Ensure qdrant-client is installed" version "$QDRANT_PYTHON_CLIENT_VERSION"
pip install --quiet "qdrant-client==${QDRANT_PYTHON_CLIENT_VERSION}" || { log error "Failed to install qdrant-client Exiting." version "$QDRANT_PYTHON_CLIENT_VERSION" ; exit 1; }

tools/check-consistency-improved.py &
pids+=($!)

# for old consistency check start 5 processes in parallel
#for _ in {1..5}; do
#  tools/check-consistency.py &
#  pids+=($!)
#done

for pid in "${pids[@]}"; do
  wait "$pid"
  exit_code=$?
  log debug "Process finished" pid "$pid" exit_code "$exit_code"
  if [ $exit_code -ne 0 ]; then
    is_data_consistent=false
    break
  fi
done

log info "Checked chaos-testing components" upload_operational "$upload_operational" search_operational "$search_operational" is_data_consistent "$is_data_consistent" measure_timestamp "$NOW" cluster_name "$QC_NAME"


if [ -z "$POSTGRES_HOST" ] || [ -z "$POSTGRES_PASSWORD" ]; then
  log error "Postgres credentials not provided"
  exit 1
fi

function postgres_query() {
    sql_query=$1
    log_cmd "docker run --rm --name $POSTGRES_CLIENT_CONTAINER_NAME jbergknoff/postgresql-client \"$POSTGRES_URL\" -c \"$sql_query\""
}

# Assume table:
# create table bfb_health (
# 	id SERIAL PRIMARY key,
# 	upload_operational BOOLEAN,
# 	search_operational BOOLEAN,
# 	is_data_consistent BOOLEAN,
# 	measure_timestamp TIMESTAMP
# );

# TODO: Rename table as cluster_health
postgres_query "INSERT INTO bfb_health (upload_operational, search_operational, is_data_consistent, measure_timestamp, cluster_name) VALUES ($upload_operational, $search_operational, $is_data_consistent, '$NOW', '$QC_NAME');"
