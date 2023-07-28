#!/usr/bin/env bash

set -euo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
ROOT="$(dirname "$SELF")"


QDRANT_API_KEY="${QDRANT_API_KEY-}"


QDRANT_HOSTS=()

for IDX in $(seq 3)
do
    QDRANT_HOSTS+=( "$("$ROOT"/clouds/hetzner/get_private_ip.sh qdrant-node-"$IDX")" )
done


ENV_CONTEXT="${QDRANT_API_KEY@A}" \
bash -x "$ROOT"/run-remote.sh qdrant-manager "$ROOT"/local/run-bfb-search.sh "${QDRANT_HOSTS[@]}"
