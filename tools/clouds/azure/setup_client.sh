#!/bin/bash

set -e

VECTOR_DB=${1:-qdrant}
DATASET=${2:-glove-100-angular}
PRIVATE_SERVER_IP=${3}

# Install poetry if not installed yet
if! command -v poetry &> /dev/null; then
    sudo apt install -y python3-pip
    python3 -m pip install poetry
    python3 -m poetry install
endif

# Clone the benchmark repo if not cloned yet
if [! -d "vector-db-benchmark" ]; then
    git clone https://github.com/qdrant/vector-db-benchmark
endif

# Run the benchmarks
cd vector-db-benchmark
nohup python3 -m poetry run python run.py --engines "${VECTOR_DB}-m-*-ef-*" --datasets $DATASET --host $PRIVATE_SERVER_IP > output.log 2>&1 &
