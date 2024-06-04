#!/bin/bash
PS4='ts=$(date "+%Y-%m-%dT%H:%M:%SZ") level=DEBUG line=$LINENO '
set -xeuo pipefail

log_with_timestamp() {
    while IFS= read -r line; do
        echo "$(date --rfc-3339=seconds --utc) $line"
    done
}
# Redirect stdout (1) and stderr (2) to a log file
exec > >(log_with_timestamp >> /var/log/collect-stats-cron.log) 2>&1

# Clone repo if not exists:
if [ ! -d "haloperidol" ]; then
    git clone https://github.com/qdrant/haloperidol.git
fi

echo "haloperidol repo is at $PWD"
cd haloperidol || exit
git pull # this can fail if repo is touched

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
