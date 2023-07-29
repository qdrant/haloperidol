#!/usr/bin/env bash

set -euo pipefail

# After machines are created, it should run qdrant cluster on them:

# - Run first node with --url and no --bootstrap
# - Run other nodes with --bootstrap parameter as a private ip of the first node

SELF="$(realpath "${BASH_SOURCE[0]}")"
ROOT="$(dirname "$SELF")"


CLOUD_NAME="${CLOUD_NAME:-hetzner}"

QDRANT_API_KEY="${QDRANT_API_KEY-}"
KILL_STORAGES="${KILL_STORAGES-}"


FIRST_NODE_PRIV_ADDR="$("$ROOT"/clouds/"$CLOUD_NAME"/get_private_ip.sh qdrant-node-1)"
FIRST_NODE_URI="http://$FIRST_NODE_PRIV_ADDR:6335"

export ENV_CONTEXT="${QDRANT_API_KEY@A} ${KILL_STORAGES@A}"

bash -x "$ROOT"/run-remote.sh qdrant-node-1 "$ROOT"/local/run-qdrant-node.sh --uri "$FIRST_NODE_URI"
bash -x "$ROOT"/run-remote.sh qdrant-node-1 "$ROOT"/common/wait-qdrant-start.sh

for NODE in qdrant-node-2 qdrant-node-3
do
	bash -x "$ROOT"/run-remote.sh "$NODE" "$ROOT"/local/run-qdrant-node.sh --bootstrap "$FIRST_NODE_URI"
	bash -x "$ROOT"/run-remote.sh "$NODE" "$ROOT"/common/wait-qdrant-start.sh
done
