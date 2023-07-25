#!/bin/bash
set -e

CONTAINER_NAME=${CONTAINER_NAME:-""}

if [[ -z "$CONTAINER_NAME" ]]
then
    echo "Please specify CONTAINER_NAME env variable"
    exit 1
fi

# Check the exit code of the container
# And if it is not 0, error out

EXIT_CODE=$(docker inspect -f '{{.State.ExitCode}}' $CONTAINER_NAME)

if [ "$EXIT_CODE" != "0" ]; then
    echo "Container $CONTAINER_NAME failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi
