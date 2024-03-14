#!/usr/bin/env bash

set -euo pipefail

function self {
	realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
	return "$?"
}

declare SELF="$(self)"
declare ROOT="$(dirname "$SELF")"

RUN_SCRIPT="$ROOT/local/collect-node-metrics.sh"

QDRANT_API_KEY=${QDRANT_API_KEY:-""}
QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}

for IDX in {0..4}; do
    QDRANT_HOSTS+=("node-${IDX}-${QDRANT_CLUSTER_URL}")
done

ENV_CONTEXT="${QDRANT_HOSTS[@]@A} ${QDRANT_API_KEY@A} ${POSTGRES_PASSWORD@A} ${POSTGRES_HOST@A}" \

RUN_SCRIPT=$RUN_SCRIPT \
	ENV_CONTEXT="${ENV_CONTEXT}" \
	SERVER_NAME=qdrant-manager \
	bash -x "$ROOT/run_remote.sh"

