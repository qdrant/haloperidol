#!/usr/bin/env bash

set -euo pipefail

# Select random node, ssh to it and restart qdrant with docker restart

SELF="$(realpath "${BASH_SOURCE[0]}")"
ROOT="$(dirname "$SELF")"


IDX=$((RANDOM % 3 + 1))

bash -x "$ROOT"/run-remote.sh qdrant-node-"$IDX" "$ROOT"/local/restart-qdrant-node.sh
