#!/bin/bash
# Clone repo if not exists:
if [ ! -d "haloperidol" ]; then
    git clone https://github.com/qdrant/haloperidol.git
fi

cd haloperidol || exit
git pull

while true; do
    echo "Collecting stats..."

    QDRANT_HOSTS_STR=$(IFS=, ; echo "${QDRANT_HOSTS[*]}")
    export QDRANT_HOSTS_STR

    tools/local/check-cluster-health.sh
    tools/local/collect-node-metrics.sh

    echo "Waiting for 15 minutes..."
    sleep 900 # 15m
done
