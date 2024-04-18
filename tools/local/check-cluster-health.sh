#!/bin/bash

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

CONTAINER_NAME=bfb-upload tools/local/check-docker-exit-code.sh
upload_operational=$([ $? -eq 0 ] && echo true || echo false)

CONTAINER_NAME=bfb-search tools/local/check-docker-exit-code.sh
search_operational=$([ $? -eq 0 ] && echo true || echo false)

tools/check-consistency.py
is_data_consistent=$([ $? -eq 0 ] && echo true || echo false)

echo "upload_operational: $upload_operational, search_operational: $search_operational, is_data_consistent: $is_data_consistent, measure_timestamp: $NOW"

docker run --rm jbergknoff/postgresql-client "postgresql://qdrant:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/postgres" -c "INSERT INTO bfb_health (upload_operational, search_operational, is_data_consistent, measure_timestamp) VALUES ($upload_operational, $search_operational, $is_data_consistent, '$NOW');"
