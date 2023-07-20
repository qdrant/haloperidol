#!/bin/bash

set -e

HCVERSION=v1.36.0

wget https://github.com/hetznercloud/cli/releases/download/${HCVERSION}/hcloud-linux-amd64.tar.gz

tar xzf hcloud-linux-amd64.tar.gz

sudo mv hcloud /usr/local/bin

