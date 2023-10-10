#!/bin/bash

set -e
set -x

VECTOR_DB=${1:-qdrant}

# Install docker and docker-compose if not installed

if [! -x "$(command -v docker)" ]; then
    apt-get update
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        jq

    mkdir -p /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update

    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    docker run hello-world
    docker-compose --version
fi

# Clone the benchmark repo if not cloned yet
if [! -d "vector-db-benchmark" ]; then
    git clone https://github.com/qdrant/vector-db-benchmark
fi

# Run database in docker:
cd vector-db-benchmark
git checkout feat/benchmark-upgrades && git pull
cd engine/servers/${VECTOR_DB}-single-node
docker compose up -d
