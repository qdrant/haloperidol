#!/bin/bash

set -e
set -x

VECTOR_DB=${1:-qdrant}
DATASET=${2:-glove-100-angular}
PRIVATE_SERVER_IP=${3}

# Install poetry if not installed yet (based on which command)
if [! which poetry ]; then
    sudo apt install -y python3-pip
    python3 -m pip install poetry
    python3 -m poetry install
fi

# Clone the benchmark repo if not cloned yet
if [! ls -d "vector-db-benchmark" ]; then
    git clone https://github.com/qdrant/vector-db-benchmark
fi

# Run the benchmarks
cd vector-db-benchmark
ls
git checkout feat/benchmark-upgrades && git pull
nohup python3 -m poetry run python run.py --engines "${VECTOR_DB}-m-*-ef-*" --datasets $DATASET --host $PRIVATE_SERVER_IP > output.log 2>&1 &
PID_BENCHMARK=$!
echo $PID_BENCHMARK > run.pid
# wait for the benchmark to finish
while ps -p $PID_BENCHMARK > /dev/null; do sleep 1; done
# wait $PID_BENCHMARK
