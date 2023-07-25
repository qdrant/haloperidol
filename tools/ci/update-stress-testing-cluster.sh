#!/usr/bin/env bash

set -euo pipefail


function self {
	realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
	return "$?"
}

declare SELF="$(self)"

declare CI="$(dirname "$SELF")"

declare ROOT="$(dirname "$CI")"
declare RUN_REMOTE="$ROOT/run_remote.sh"

declare HETZNER="$ROOT/clouds/hetzner"
declare GET_PRIVATE_IP="$HETZNER/get_private_ip.sh"

declare LOCAL="$ROOT/local"
declare RUN_QDRANT_NODE="$LOCAL/run-qdrant-node.sh"
declare RUN_BFB_UPLOAD="$LOCAL/run-bfb-upload.sh"


function update-qdrant-nodes {
	declare BOOTSTRAP=''

	for IDX in $(seq 3)
	do
		declare NODE=qdrant-node-"$IDX"

		declare PRIV_ADDR; PRIV_ADDR="$("$GET_PRIVATE_IP" "$NODE")"

		ENV_CONTEXT="${BOOTSTRAP-}" \
		RUN_SCRIPT="$RUN_QDRANT_NODE" \
		SERVER_NAME="$NODE" \
		"$RUN_REMOTE"

		if [[ ! "${BOOTSTRAP-}" ]]
		then
			BOOTSTRAP="--bootstrap $ADDR"
		fi

		if declare -a QDRANT_HOSTS &>/dev/null
		then
			QDRANT_HOSTS+=( "$PRIV_ADDR" )
		fi
	done
}

function update-bfb-upload {
	ENV_CONTEXT="QDRANT_HOSTS='${QDRANT_HOSTS[@]}'" \
	RUN_SCRIPT="$RUN_QDRANT_NODE" \
	SERVER_NAME=qdrant-bfb-upload \
	"$RUN_REMOTE"
}


declare QDRANT_HOSTS=()
update-qdrant-nodes
update-bfb-upload
