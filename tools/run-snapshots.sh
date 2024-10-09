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
declare RUN_SNAPSHOTS_PROCESS="$LOCAL/run-snapshots.sh"

QDRANT_API_KEY=${QDRANT_API_KEY:-""}
QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}
QC_NAME=${QC_NAME:-"qdrant-chaos-testing"}

BG_TASK_NAME="run-snapshots"
if [ "$QC_NAME" == "qdrant-chaos-testing-debug" ]; then
    BG_TASK_NAME="${BG_TASK_NAME}-debug"
elif [ "$QC_NAME" == "qdrant-chaos-testing-three" ]; then
    BG_TASK_NAME="${BG_TASK_NAME}-three"
fi

for IDX in {0..3}; do
    QDRANT_HOSTS+=("node-${IDX}-${QDRANT_CLUSTER_URL}")
done

# shellcheck disable=SC2124
ENV_CONTEXT="${QDRANT_API_KEY@A} ${QDRANT_HOSTS[@]@A} ${QC_NAME@A}" \
RUN_SCRIPT="$RUN_SNAPSHOTS_PROCESS" \
BG_TASK_NAME="$BG_TASK_NAME" \
SERVER_NAME=qdrant-manager \
bash -x "$RUN_REMOTE"
