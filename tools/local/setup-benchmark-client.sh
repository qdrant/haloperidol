#!/bin/bash

set -e
set -x

VECTOR_DB=${1:-qdrant}
BRANCH=${2:-"master"}

cd vector-db-benchmark
git checkout $BRANCH && git pull

poetry install
nohup python3 -m poetry run python run.py --engines "${VECTOR_DB}-m-*-ef-*" --datasets $DATASET --host $PRIVATE_SERVER_IP >> ${VECTOR_DB}.log 2>&1 &
PID_BENCHMARK=$!
echo $PID_BENCHMARK > benchmark.pid
tail -f ${VECTOR_DB}.log
wait $PID_BENCHMARK
