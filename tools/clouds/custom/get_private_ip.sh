#!/bin/bash

set -e
# Get ip of the private network interface of Hetzner server
# Using `hcloud` CLI tool

# Usage: ./get_private_ip.sh <server_name>

# Example: ./get_private_ip.sh benchmark-server-1


SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

SERVER_IP=$(jq ".[\"${1}\"].private_ip" -r $SCRIPTPATH/data.json)

echo "${SERVER_IP}"
