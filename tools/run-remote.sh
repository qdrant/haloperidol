#!/usr/bin/env bash

set -euo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
ROOT="$(dirname "$SELF")"


CLOUD_NAME="${CLOUD_NAME:-hetzner}"
SSH_USER="${SSH_USER:-root}"

ENV_CONTEXT="${ENV_CONTEXT-}"

SERVER_NAME="$1"
SCRIPT="$2"
ARGS=( "${@:3}" )


SERVER_IP="$("$ROOT"/clouds/"$CLOUD_NAME"/get_public_ip.sh "$SERVER_NAME")"

echo "$ENV_CONTEXT" | cat - "$SCRIPT" | ssh -oStrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" bash -x "${ARGS[@]}"
