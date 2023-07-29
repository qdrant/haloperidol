#!/usr/bin/env bash

set -euo pipefail

function self {
	realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
	return "$?"
}

declare SELF="$(self)"
declare ROOT="$(dirname "$SELF")"

RUN_SCRIPT="$ROOT/local/check-docker-exit-code.sh"

CONTAINER_NAME=bfb-upload

RUN_SCRIPT=$RUN_SCRIPT \
	ENV_CONTEXT="${CONTAINER_NAME@A}" \
	SERVER_NAME=qdrant-manager \
	bash -x "$ROOT/run_remote.sh"


CONTAINER_NAME=bfb-search

RUN_SCRIPT=$RUN_SCRIPT \
	ENV_CONTEXT="${CONTAINER_NAME@A}" \
	SERVER_NAME=qdrant-manager \
	bash -x "$ROOT/run_remote.sh"
