#!/usr/bin/env bash

set -euo pipefail

function self {
	realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
	return "$?"
}


declare SELF ROOT
SELF="$(self)"
ROOT="$(dirname "$SELF")"

RUN_SCRIPT="$ROOT/local/collect-node-metrics.sh"

QDRANT_API_KEY=${QDRANT_API_KEY:-""}
QDRANT_CLUSTER_URL=${QDRANT_CLUSTER_URL:-""}
QC_NAME=${QC_NAME:-""}

for IDX in {0..4}; do
    QDRANT_HOSTS+=("node-${IDX}-${QDRANT_CLUSTER_URL}")
done

# shellcheck disable=SC2124
ENV_CONTEXT="${QDRANT_HOSTS[@]@A} ${QDRANT_API_KEY@A} ${POSTGRES_PASSWORD@A} ${POSTGRES_HOST@A} ${QC_NAME@A}" \

RUN_SCRIPT=$RUN_SCRIPT \
	ENV_CONTEXT="${ENV_CONTEXT}" \
	SERVER_NAME=qdrant-manager \
	bash -x "$ROOT/run_remote.sh"

