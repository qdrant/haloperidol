#!/bin/bash

set -e
set -x

VECTOR_DB=${VECTOR_DB:-qdrant}
BRANCH=${BRANCH:-master}

if [ -d "./vector-db-benchmark" ]; then
    echo "vector-db-benchmark repo already exists"
else
    git clone https://github.com/qdrant/vector-db-benchmark
fi

cd vector-db-benchmark
git checkout $BRANCH && git pull

# stop all running containers:
RUNNING_CONTAINERS=$(docker ps -q)
if [ -n "$RUNNING_CONTAINERS" ]; then
    docker stop $RUNNING_CONTAINERS
fi

cd engine/servers/${VECTOR_DB}-single-node
docker compose up -d

sleep 10 # OR Use retry curl on "Connection refused" or "Connection reset by peer"
# wait for the engine to start
if [ "$VECTOR_DB" == "milvus" ]; then
    curl --max-time 120 http://localhost:19530/v1/vector/collections
elif [ "$VECTOR_DB" == "qdrant" ]; then
    curl --max-time 120 http://localhost:6333
elif [ "$VECTOR_DB" == "elasticsearch" ]; then
    sleep 15 # FIXME: detect "connection reset by peer and retry" instead of sleeping
    curl --max-time 120 http://localhost:9200/_cluster/health
fi
