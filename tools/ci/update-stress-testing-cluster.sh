#!/usr/bin/env bash

set -euo pipefail


function self {
	realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
	return "$?"
}

declare SELF="$(self)"

declare CI="$(dirname "$SELF")"

declare ROOT="$(dirname "$CI")"
declare RUN_QDRANT_CLUSTER="$ROOT/run_qdrant_cluster.sh"
declare RUN_REMOTE="$ROOT/run_remote.sh"

declare HETZNER="$ROOT/clouds/hetzner"
declare GET_PRIVATE_IP="$HETZNER/get_private_ip.sh"

declare LOCAL="$ROOT/local"
declare RUN_BFB_UPLOAD="$LOCAL/run-bfb-upload.sh"


function update-qdrant-nodes {
	"$RUN_QDRANT_CLUSTER"
}

function update-bfb-upload {
	declare QDRANT_HOSTS=()

	for IDX in "$(seq 3)"
	do
		QDRANT_HOSTS+=( "$("$GET_PRIVATE_IP" qdrant-node-"$IDX")" )
	done

	ENV_CONTEXT="QDRANT_HOSTS='${QDRANT_HOSTS[@]}'" \
	RUN_SCRIPT="$RUN_QDRANT_NODE" \
	SERVER_NAME=qdrant-manager \
	"$RUN_REMOTE"
}


update-qdrant-nodes
update-bfb-upload
