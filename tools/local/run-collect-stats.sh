#!/bin/bash
# Clone repo if not exists:
if [ ! -d "haloperidol" ]; then
    git clone https://github.com/qdrant/haloperidol.git
fi

cd haloperidol || exit

while true; do
    echo "Collecting stats..."

    tools/local/check-cluster-health.sh
    tools/local/collect-node-metrics.sh

    echo "Waiting for 15 minutes..."
    sleep 900 # 15m
done
