#!/bin/bash

set -e

# Install MC

wget https://dl.min.io/client/mc/release/linux-amd64/mc

sudo mv hcloud /usr/local/bin
chmod +x mc


# if GCS_KEY and GCS_SECRET are set, configure mc to use them

if [ -z "${GCS_KEY}" ] || [ -z "${GCS_SECRET}" ]; then
    echo "GCS_KEY or GCS_SECRET not set, skipping mc configuration"
    exit 0
fi

./mc alias set qdrant https://storage.googleapis.com "${GCS_KEY}" "${GCS_SECRET}"
