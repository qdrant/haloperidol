#!/bin/bash


set -e

# Select random node, ssh to it and restart qdrant with docker restart

SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
CLOUD_NAME=${CLOUD_NAME:-"hetzner"}


SERVER_NAME="qdrant-manager"

POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-}


RUN_SCRIPT="${SCRIPT_PATH}/local/install-postgres.sh" \
    ENV_CONTEXT="${POSTGRES_PASSWORD@A}" \
    SERVER_NAME=${SERVER_NAME} \
    bash -x "$SCRIPT_PATH/run_remote.sh"


