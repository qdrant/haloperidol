#!/usr/bin/env bash

set -euo pipefail


function self {
    realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
    return "$?"
}

declare SELF="$(self)"

declare ROOT="$(dirname "$SELF")"
declare RUN_REMOTE="$ROOT/run_remote.sh"

declare HETZNER="$ROOT/clouds/hetzner"
declare GET_PRIVATE_IP="$HETZNER/get_private_ip.sh"

declare LOCAL="$ROOT/local"
declare RUN_BFB_SEARCH="$LOCAL/run-bfb-search.sh"


declare QDRANT_HOSTS=()

QDRANT_API_KEY=${QDRANT_API_KEY:-""}

for IDX in $(seq 3)
do
    QDRANT_HOSTS+=( "$("$GET_PRIVATE_IP" qdrant-node-"$IDX")" )
done

ENV_CONTEXT="${QDRANT_HOSTS[@]@A} ${QDRANT_API_KEY@A}" \
RUN_SCRIPT="$RUN_BFB_SEARCH" \
SERVER_NAME=qdrant-manager \
bash -x "$RUN_REMOTE"
