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
declare RUN_BFB_UPLOAD="$LOCAL/run-bfb-upload.sh"


declare QDRANT_HOSTS=()

QDRANT_API_KEY=${QDRANT_API_KEY:-""}
QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}

QDRANT_HOSTS+=("${QDRANT_CLUSTER_URL}")

ENV_CONTEXT="${QDRANT_HOSTS[@]@A} ${QDRANT_API_KEY@A}" \
RUN_SCRIPT="$RUN_BFB_UPLOAD" \
SERVER_NAME=qdrant-manager \
bash -x "$RUN_REMOTE"
