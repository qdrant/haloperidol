#!/usr/bin/env bash

set -euo pipefail

# This script should create N virtual machies with docker installed and configured
# Plus one virtual machine with docker for generating load

SELF="$(realpath "${BASH_SOURCE[0]}")"
ROOT="$(dirname "$SELF")"


CLOUD_NAME="${CLOUD_NAME:-hetzner}"
SERVER_TYPE="${SERVER_TYPE:-cx11}"


export SERVER_TYPE

for SERVER_NAME in qdrant-node-1 qdrant-node-2 qdrant-node-3 qdrant-manager
do
	bash -x "$ROOT"/clouds/"$CLOUD_NAME"/create_and_install.sh "$SERVER_NAME"
done
