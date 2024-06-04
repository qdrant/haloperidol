#!/bin/bash
PS4='ts=$(date "+%Y-%m-%dT%H:%M:%SZ") level=DEBUG line=$LINENO '
set -xeuo pipefail

log_with_timestamp() {
    while IFS= read -r line; do
        ts=$(date "+%Y-%m-%dT%H:%M:%SZ")
        echo "ts=$ts $line"
    done
}
# Redirect stdout (1) and stderr (2) to a log file
exec > >(log_with_timestamp >> /var/log/collect-stats-cron.log) 2>&1

# Clone repo if not exists:
if [ ! -d "haloperidol" ]; then
    git clone https://github.com/qdrant/haloperidol.git
fi

cd haloperidol || exit
git pull # this can fail if repo is touched

while true; do
    echo "level=INFO msg=\"Collect stats script triggered\""

    QDRANT_HOSTS_STR=$(IFS=, ; echo "${QDRANT_HOSTS[*]}")
    export QDRANT_HOSTS_STR

    tools/local/check-cluster-health.sh
    tools/local/collect-node-metrics.sh

    echo "level=INFO msg=\"Sleeping for 1m\""
    sleep 60 # 1m
done
