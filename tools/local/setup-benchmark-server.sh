#!/bin/bash

set -e
set -x

VECTOR_DB=${1:-qdrant}
BRANCH=${2:-"master"}

if [! -d "vector-db-benchmark" ]; then
    git clone https://github.com/qdrant/vector-db-benchmark
fi

cd vector-db-benchmark
git checkout $BRANCH && git pull

cd engine/servers/${VECTOR_DB}-single-node
docker compose up -d
