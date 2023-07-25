#!/usr/bin/env bash

set -euo pipefail

BFB_CONTAINER_NAME=bfb-upload

EXIT_CODE=$(docker inspect ${BFB_CONTAINER_NAME} --format='{{.State.ExitCode}}')

if [ "$EXIT_CODE" != "0" ]; then
    echo "BFB failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi
