#!/usr/bin/env bash

set -euo pipefail


function self {
    realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
    return "$?"
}

declare SELF="$(self)"

declare ROOT="$(dirname "$SELF")"
declare RUN_REMOTE="$ROOT/run_remote.sh"

declare LOCAL="$ROOT/local"
declare RUN_COLLECT_STATS="$LOCAL/run-collect-stats.sh"

HCLOUD_TOKEN=${HCLOUD_TOKEN:-""}
QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}
QDRANT_API_KEY=${QDRANT_API_KEY:-""}
POSTGRES_HOST=${POSTGRES_HOST:-""}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-""}
BG_TASK_NAME=${BG_TASK_NAME:-"collect-stats"}

QDRANT_HOSTS=()
for IDX in {0..3}; do
    QDRANT_HOSTS+=("node-${IDX}-${QDRANT_CLUSTER_URL}")
done

SERVER_NAME=${SERVER_NAME:-"qdrant-manager"}

ENV_CONTEXT="${HCLOUD_TOKEN@A} ${QDRANT_CLUSTER_URL@A} ${QDRANT_API_KEY@A} ${POSTGRES_HOST@A} ${POSTGRES_PASSWORD@A} ${QDRANT_HOSTS[@]@A}" \
RUN_SCRIPT="$RUN_COLLECT_STATS" \
SERVER_NAME="$SERVER_NAME" \
BG_TASK_NAME="$BG_TASK_NAME" \
bash -x "$RUN_REMOTE"
