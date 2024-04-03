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

python3 ./tools/check-consistency.py

if [ $? -ne 0 ]; then
    is_data_consistent=false
else
    is_data_consistent=true
fi

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

if [ "$upload_operational" = false ] || [ "$search_operational" = false ] || [ "$is_data_consistent" = false ]; then
	exit 1
fi

exit 1 # temporary for testing
