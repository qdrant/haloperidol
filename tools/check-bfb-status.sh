#!/usr/bin/env bash

set -euo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
ROOT="$(dirname "$SELF")"

bash -x "$ROOT"/run-remote.sh qdrant-manager "$ROOT"/local/check-docker-exit-code.sh bfb-upload
bash -x "$ROOT"/run-remote.sh qdrant-manager "$ROOT"/local/check-docker-exit-code.sh bfb-search
