#!/bin/bash


# Run postgres in a docker container with given credentials

POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-}

if [[ -z "$POSTGRES_PASSWORD" ]]
then
    echo "Please set POSTGRES_PASSWORD environment variable"
    exit 1
fi

docker run \
    --name qdrant-postgres \
    -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
    -e POSTGRES_USER=qdrant \
    -e POSTGRES_DB=postgres \
    -v $(pwd)/qdrant-postgres:/var/lib/postgresql/data \
    -p 5432:5432 \
    -d \
    postgres:15


# crete a table in the database

docker exec -it qdrant-postgres psql -U qdrant -d postgres -c "
create table benchmark (
	id SERIAL PRIMARY key,
	engine VARCHAR(255),
	measure_timestamp TIMESTAMP,
	upload_time real,
	indexing_time real,
	rps real,
	mean_precisions real,
	p95_time real,
	p99_time real,
	memory_usage real
);
"


