#!/bin/bash
# PS4='ts=$(date -u "+%Y-%m-%dT%H:%M:%SZ") level=trace line=$LINENO '; set -x; # too verbose; disabled
# trap 'echo "ts=$(date -u "+%Y-%m-%dT%H:%M:%SZ") level=trace line=$LINENO cmd=\"$BASH_COMMAND\""' DEBUG # less verbose; but still noisy; disabled

# Fail on error:
set -e

dirname=$(basename "$PWD")

if [ "$dirname" != "haloperidol" ]; then # introduced condition to run locally smoothly
    # Clone repo if not exists:
    if [ ! -d "haloperidol" ]; then
        git clone https://github.com/qdrant/haloperidol.git
    fi

    cd haloperidol || exit
    git pull # this can fail if repo is touched
fi

set +e

source "tools/local/logging.sh" # Can be imported only after we are in haloperidol dir

QC_NAME=${QC_NAME:-"qdrant-chaos-testing"}
QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}
QDRANT_API_KEY=${QDRANT_API_KEY:-""}
QDRANT_PYTHON_CLIENT_VERSION=${QDRANT_PYTHON_CLIENT_VERSION:-"1.12.1"}

if [ -z "$QDRANT_CLUSTER_URL" ] || [ -z "$QDRANT_API_KEY" ]; then
    log error "Must pass QDRANT_CLUSTER_URL and QDRANT_API_KEY"
    exit 0
fi

QDRANT_HOSTS=()
for IDX in {0..4}; do
    QDRANT_HOSTS+=("node-${IDX}-${QDRANT_CLUSTER_URL}")
done

function handle_error() {
    local exit_code error_line error_command
    exit_code=$1
    error_line=${BASH_LINENO[0]}
    error_command=$BASH_COMMAND
    log error "Error occurred" line "$error_line" cmd "$error_command" exit_code "$exit_code"
}

# Trap ERR signal and call handle_error function
trap 'exit_code=$?; handle_error "$exit_code"' ERR

while true; do
    log debug "Collect stats script triggered"

    QDRANT_HOSTS_STR=$(IFS=, ; echo "${QDRANT_HOSTS[*]}")
    export QDRANT_HOSTS_STR

    tools/local/check-cluster-health.sh
    # python3 tools/check-empty-payload.py
    tools/local/collect-node-metrics.sh
    tools/local/check-ps.sh

    log info "Sleeping for 1m"
    sleep 60 # 1m
done
