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

python3 -m poetry install
nohup python3 -m poetry run python run.py --engines "${VECTOR_DB}-m-*-ef-*" --datasets $DATASET --host $PRIVATE_SERVER_IP >> ${VECTOR_DB}.log 2>&1 &
PID_BENCHMARK=$!
echo $PID_BENCHMARK > benchmark.pid
wait $PID_BENCHMARK
