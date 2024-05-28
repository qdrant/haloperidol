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
declare RUN_SNAPSHOTS_PROCESS="$LOCAL/run-snapshots.sh"

QDRANT_API_KEY=${QDRANT_API_KEY:-""}
QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}

for IDX in {0..3}; do
    QDRANT_HOSTS+=("node-${IDX}-${QDRANT_CLUSTER_URL}")
done

ENV_CONTEXT="${QDRANT_API_KEY@A} ${QDRANT_HOSTS[@]@A}" \
RUN_SCRIPT="$RUN_SNAPSHOTS_PROCESS" \
BG_TASK_NAME="run-snapshots" \
SERVER_NAME=qdrant-manager \
bash -x "$RUN_REMOTE"
