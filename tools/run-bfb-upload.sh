#!/usr/bin/env bash

set -euo pipefail


function self {
    realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
    return "$?"
}

declare SELF="$(self)"
declare ROOT="$(dirname "$SELF")"
declare HETZNER="$ROOT/clouds/hetzner"

declare GET_PRIVATE_IP="$HETZNER/get_private_ip.sh"


declare QDRANT_HOSTS=()

for IDX in "$(seq 3)"
do
    QDRANT_HOSTS+=( "$("$GET_PRIVATE_IP" qdrant-node-"$IDX")" )
done

ENV_CONTEXT="QDRANT_HOSTS='${QDRANT_HOSTS[@]}'" \
RUN_SCRIPT="$RUN_BFB_UPLOAD" \
SERVER_NAME=qdrant-manager \
"$RUN_REMOTE"
