#!/bin/bash
PS4='ts=$(date "+%Y-%m-%dT%H:%M:%SZ") level=DEBUG line=$LINENO '
set -x

log_with_timestamp() {
    while IFS= read -r line; do
        # ts=$(date "+%Y-%m-%dT%H:%M:%SZ") # ts=$ts
        echo "$line"
    done
}
# Redirect stdout (1) and stderr (2) to a log file
exec > >(log_with_timestamp >> /var/log/collect-stats-cron.log) 2>&1

function handle_error() {
    local error_code error_line error_command ts
    error_code=$?
    error_line=${BASH_LINENO[0]}
    error_command=$BASH_COMMAND
    ts=$(date +"%Y-%m-%d %H:%M:%S" --utc)
    echo "ts=$ts level=ERROR line=$error_line cmd=\"$error_command\" exit_code=$error_code"
}

# Trap ERR signal and call handle_error function
trap 'handle_error' ERR

# Fail on error:
set -e
# Clone repo if not exists:
if [ ! -d "haloperidol" ]; then
    git clone https://github.com/qdrant/haloperidol.git
fi

cd haloperidol || exit
git pull # this can fail if repo is touched
set +e

while true; do
    echo "level=INFO msg=\"Collect stats script triggered\""

    QDRANT_HOSTS_STR=$(IFS=, ; echo "${QDRANT_HOSTS[*]}")
    export QDRANT_HOSTS_STR

    tools/local/check-cluster-health.sh
    python3 tools/check-empty-payload.py
    tools/local/collect-node-metrics.sh

    echo "level=INFO msg=\"Sleeping for 1m\""
    sleep 60 # 1m
done
