#!/usr/bin/env bash

PS4='ts=$(date "+%Y-%m-%dT%H:%M:%SZ") level=DEBUG line=$LINENO '
set -uo pipefail
set -x

function self {
	realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
	return "$?"
}

declare SELF ROOT
SELF="$(self)"
ROOT="$(dirname "$SELF")"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

RUN_SCRIPT="$ROOT/local/check-docker-exit-code.sh"

QC_NAME=${QC_NAME:-"qdrant-chaos-testing"}

if [ "$QC_NAME" == "qdrant-chaos-testing" ]; then
    CONTAINER_NAME="bfb-upload"
elif [ "$QC_NAME" == "qdrant-chaos-testing-debug" ]; then
    CONTAINER_NAME="bfb-upload-debug"
else
    echo "Unexpected QdrantCluster $QC_NAME"
    exit 1
fi
RUN_SCRIPT=$RUN_SCRIPT \
	ENV_CONTEXT="${CONTAINER_NAME@A}" \
	SERVER_NAME=qdrant-manager \
	bash -x "$ROOT/run_remote.sh"
exit_code=$?
upload_operational=$([ $exit_code -eq 0 ] && echo true || echo false)

if [ "$QC_NAME" == "qdrant-chaos-testing" ]; then
    CONTAINER_NAME="bfb-search"
elif [ "$QC_NAME" == "qdrant-chaos-testing-debug" ]; then
    CONTAINER_NAME="bfb-search-debug"
else
    echo "Unexpected QdrantCluster $QC_NAME"
    exit 1
fi
RUN_SCRIPT=$RUN_SCRIPT \
	ENV_CONTEXT="${CONTAINER_NAME@A}" \
	SERVER_NAME=qdrant-manager \
	bash -x "$ROOT/run_remote.sh"
exit_code=$?
search_operational=$([ $exit_code -eq 0 ] && echo true || echo false)

echo "Checking data consistency"
python3 ./tools/check-consistency.py
exit_code=$?
is_data_consistent=$([ $exit_code -eq 0 ] && echo true || echo false)

echo "upload_operational: $upload_operational, search_operational: $search_operational, is_data_consistent: $is_data_consistent, measure_timestamp: $NOW, cluster_name: $QC_NAME"

# Assume table:
# create table bfb_health (
# 	id SERIAL PRIMARY key,
# 	upload_operational BOOLEAN,
# 	search_operational BOOLEAN,
# 	is_data_consistent BOOLEAN,
# 	measure_timestamp TIMESTAMP
# );

# TODO: Rename table as cluster_health
docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO bfb_health (upload_operational, search_operational, is_data_consistent, measure_timestamp, cluster_name) VALUES ($upload_operational, $search_operational, $is_data_consistent, '$NOW', '$QC_NAME');"

if [ "$upload_operational" = false ] || [ "$search_operational" = false ] || [ "$is_data_consistent" = false ]; then
	echo "::set-output name=failed::true"
fi

