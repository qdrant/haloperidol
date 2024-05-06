#!/bin/bash

# Redirect stdout (1) and stderr (2) to a log file
exec >/var/log/collect-stats.log 2>&1

# Clone repo if not exists:
if [ ! -d "haloperidol" ]; then
    git clone https://github.com/qdrant/haloperidol.git
fi

cd haloperidol || exit
git pull

while true; do
    echo "==================="
    echo "Collecting stats..."

    QDRANT_HOSTS_STR=$(IFS=, ; echo "${QDRANT_HOSTS[*]}")
    export QDRANT_HOSTS_STR

    tools/local/check-cluster-health.sh
    tools/local/collect-node-metrics.sh

    echo "Waiting for 1min..."
    sleep 60 # 1m
done
