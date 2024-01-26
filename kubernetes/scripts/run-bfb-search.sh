#!/bin/bash

set -euo pipefail

BFB_PARAMETERS=" \
    --uri $QDRANT_URL \
    --keywords 10 \
    --dim 768 \
    -n 1000 \
    --threads 1 \
    --parallel 1 \
    --quantization scalar \
    --timing-threshold 1 \
    --skip-create \
    --skip-upload \
    --skip-wait-index \
    --search \
    --search-limit 10 \
    --quantization-rescore true \
"

while true; do
    ./bfb ${BFB_PARAMETERS}
    sleep 10
done
