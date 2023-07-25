#!/usr/bin/env bash

set -euo pipefail

function self {
	realpath "${BASH_SOURCE[0]}" || which "${BASH_SOURCE[0]}"
	return "$?"
}

declare SELF="$(self)"
declare ROOT="$(dirname "$SELF")"

RUN_SCRIPT="$ROOT/local/check-bfb-status.sh" \
SERVER_NAME=qdrant-manager \
bash -x "$ROOT/run_remote.sh"
