#!/bin/bash

set -euo pipefail

POD_TO_KILL=$(kubectl get pods -n haloperidol -o name | grep qdrant-haloperidol- | shuf | head -n 1)

kubectl delete "${POD_TO_KILL}" -n haloperidol
