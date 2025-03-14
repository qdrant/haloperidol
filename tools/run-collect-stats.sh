#!/usr/bin/env bash

set -euo pipefail


function self {
    realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
    return "$?"
}

declare SELF ROOT
SELF="$(self)"
ROOT="$(dirname "$SELF")"

declare RUN_REMOTE="$ROOT/run_remote.sh"

declare LOCAL="$ROOT/local"
declare RUN_COLLECT_STATS="$LOCAL/run-collect-stats.sh"

HCLOUD_TOKEN=${HCLOUD_TOKEN:-""}
QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}
QC_NAME=${QC_NAME:-"qdrant-chaos-testing"}
QDRANT_PYTHON_CLIENT_VERSION=${QDRANT_PYTHON_CLIENT_VERSION:-"1.12.1"}
QDRANT_API_KEY=${QDRANT_API_KEY:-""}
POSTGRES_HOST=${POSTGRES_HOST:-""}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-""}
LOG_FILE_NAME="${QC_NAME}-collect-stats-cron.log"

BG_TASK_NAME=${BG_TASK_NAME:-"collect-stats"}
if [ "$QC_NAME" == "qdrant-chaos-testing-debug" ]; then
    BG_TASK_NAME="${BG_TASK_NAME}-debug"
elif [ "$QC_NAME" == "qdrant-chaos-testing-three" ]; then
    BG_TASK_NAME="${BG_TASK_NAME}-three"
fi

SERVER_NAME=${SERVER_NAME:-"qdrant-manager"}
QDRANT_PYTHON_CLIENT_VERSION=${QDRANT_PYTHON_CLIENT_VERSION:-"1.12.1"}

# shellcheck disable=SC2124
ENV_CONTEXT="${HCLOUD_TOKEN@A} ${QDRANT_CLUSTER_URL@A} ${QDRANT_API_KEY@A} ${POSTGRES_HOST@A} ${POSTGRES_PASSWORD@A} ${QC_NAME@A} ${QDRANT_PYTHON_CLIENT_VERSION@A}" \
RUN_SCRIPT="$RUN_COLLECT_STATS" \
SERVER_NAME="$SERVER_NAME" \
BG_TASK_NAME="$BG_TASK_NAME" \
LOG_FILE_NAME="$LOG_FILE_NAME" \
bash -x "$RUN_REMOTE"
