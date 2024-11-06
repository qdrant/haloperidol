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
declare RUN_BFB_UPLOAD="$LOCAL/run-bfb-upload.sh"


declare QDRANT_HOSTS=()

QDRANT_API_KEY=${QDRANT_API_KEY:-""}
QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}
QC_NAME=${QC_NAME:-""}
if [ "$QC_NAME" == "qdrant-chaos-testing-three" ]; then
  QDRANT_HOSTS=( "node-0-${QDRANT_CLUSTER_URL}" "node-1-${QDRANT_CLUSTER_URL}" )
else
  QDRANT_HOSTS+=("${QDRANT_CLUSTER_URL}")
fi


# shellcheck disable=SC2124
ENV_CONTEXT="${QDRANT_HOSTS[@]@A} ${QDRANT_API_KEY@A} ${QC_NAME@A}" \
RUN_SCRIPT="$RUN_BFB_UPLOAD" \
SERVER_NAME=qdrant-manager \
bash -x "$RUN_REMOTE"
