#!/bin/bash

PS4='ts=$(date "+%Y-%m-%dT%H:%M:%SZ") level=DEBUG line=$LINENO '
set -x

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

QC_NAME=${QC_NAME:-"qdrant-chaos-testing"}

if [ "$QC_NAME" == "qdrant-chaos-testing" ]; then
    UPLOAD_CONTAINER_NAME="bfb-upload"
    SEARCH_CONTAINER_NAME="bfb-search"
    POSTGRES_CLIENT_CONTAINER_NAME="postgres-client"
elif [ "$QC_NAME" == "qdrant-chaos-testing-debug" ]; then
    UPLOAD_CONTAINER_NAME="bfb-upload-debug"
    SEARCH_CONTAINER_NAME="bfb-search-debug"
    POSTGRES_CLIENT_CONTAINER_NAME="postgres-client-debug"
else
    echo "Unexpected QdrantCluster $QC_NAME"
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

for _ in {1..5}; do
  tools/check-consistency.py &
  pids+=($!)
done


for pid in "${pids[@]}"; do
  wait "$pid"
  exit_code=$?
  echo "level=INFO msg=\"Process finished\" pid=$pid exit_code=$exit_code"
  if [ $exit_code -ne 0 ]; then
    is_data_consistent=false
    break
  fi
done

echo "level=INFO msg=\"Checked chaos-testing components\" upload_operational=$upload_operational search_operational=$search_operational is_data_consistent=$is_data_consistent measure_timestamp=\"$NOW\" cluster_name=$QC_NAME"

# Assume table:
# create table bfb_health (
# 	id SERIAL PRIMARY key,
# 	upload_operational BOOLEAN,
# 	search_operational BOOLEAN,
# 	is_data_consistent BOOLEAN,
# 	measure_timestamp TIMESTAMP
# );

# TODO: Rename table as cluster_health
docker run --rm --name $POSTGRES_CLIENT_CONTAINER_NAME jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO bfb_health (upload_operational, search_operational, is_data_consistent, measure_timestamp, cluster_name) VALUES ($upload_operational, $search_operational, $is_data_consistent, '$NOW', '$QC_NAME');"
