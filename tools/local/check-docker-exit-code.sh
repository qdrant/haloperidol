#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="$1"

# Check if container is running
IS_RUNNING="$(docker inspect "$CONTAINER_NAME" --format='{{ .State.Running }}' 2>/dev/null)"

# Error out if container is not running
if [[ $IS_RUNNING != true ]]
then
    echo "Container $CONTAINER_NAME is not running" >&2
    exit 1
fi

# Check the exit code of the container...
EXIT_CODE="$(docker inspect "$CONTAINER_NAME" --format='{{ .State.ExitCode }}')"

# ...and if it is not 0, error out
if [[ $EXIT_CODE != 0 ]]
then
    echo "Container $CONTAINER_NAME failed with exit code $EXIT_CODE" >&2
    exit "$EXIT_CODE"
fi
