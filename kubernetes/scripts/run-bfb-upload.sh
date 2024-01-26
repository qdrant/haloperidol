#!/bin/bash

set -euo pipefail

BFB_PARAMETERS=" \
    --uri $QDRANT_URL \
    --replication-factor 2 \
    --keywords 10 \
    --dim 768 \
    -n 1000000 \
    --batch-size 50 \
    --threads 1 \
    --parallel 1 \
    --wait-on-upsert \
    --create-if-missing \
    --quantization scalar \
    --timing-threshold 1 \
    --on-disk-vectors true \
    --max-id 200000 \
    --delay 100 \
"

while true; do
    ./bfb ${BFB_PARAMETERS}
    sleep 10
done
