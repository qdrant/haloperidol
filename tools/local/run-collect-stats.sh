#!/bin/bash
# PS4='ts=$(date -u "+%Y-%m-%dT%H:%M:%SZ") level=trace line=$LINENO '; set -x; # too verbose; disabled
# trap 'echo "ts=$(date -u "+%Y-%m-%dT%H:%M:%SZ") level=trace line=$LINENO cmd=\"$BASH_COMMAND\""' DEBUG # less verbose; but still noisy; disabled

# Fail on error:
set -e
# Clone repo if not exists:
if [ ! -d "haloperidol" ]; then
    git clone https://github.com/qdrant/haloperidol.git
fi

cd haloperidol || exit
git pull # this can fail if repo is touched
set +e

source "tools/local/logging.sh" # Can be imported only after we are in haloperidol dir

log_with_timestamp() {
    while IFS= read -r line; do
        # ts=$(date "+%Y-%m-%dT%H:%M:%SZ") # ts=$ts
        echo "$line"
    done
}

QC_NAME=${QC_NAME:-"qdrant-chaos-testing"}
QDRANT_PYTHON_CLIENT_VERSION=${QDRANT_PYTHON_CLIENT_VERSION:-"1.12.1"}

LOGGING_DIR="/var/log"
LOGGING_FILE="${QC_NAME}-collect-stats-cron.log"

# Redirect stdout (1) and stderr (2) to a log file
exec > >(log_with_timestamp >> "${LOGGING_DIR}/${LOGGING_FILE}") 2>&1

function handle_error() {
    local exit_code error_line error_command
    exit_code=$1
    error_line=${BASH_LINENO[0]}
    error_command=$BASH_COMMAND
    log error "Error occurred" line "$error_line" cmd "$error_command" exit_code "$exit_code"
}

# Trap ERR signal and call handle_error function
trap 'exit_code=$?; handle_error "$exit_code"' ERR


log debug "Ensure 'qdrant-client' version '${QDRANT_PYTHON_CLIENT_VERSION}' is installed..."
pip install --quiet "qdrant-client==${QDRANT_PYTHON_CLIENT_VERSION}" || { log error "Failed to install qdrant-client version ${QDRANT_PYTHON_CLIENT_VERSION}. Exiting."; exit 1; }

while true; do
    log info "Collect stats script triggered"

    QDRANT_HOSTS_STR=$(IFS=, ; echo "${QDRANT_HOSTS[*]}")
    export QDRANT_HOSTS_STR

    tools/local/check-cluster-health.sh
    # python3 tools/check-empty-payload.py
    tools/local/collect-node-metrics.sh

    log info "Sleeping for 1m"
    sleep 60 # 1m
done
