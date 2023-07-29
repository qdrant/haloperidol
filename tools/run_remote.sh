#!/bin/bash

set -e

SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
CLOUD_NAME=${CLOUD_NAME:-"hetzner"}


RUN_SCRIPT=${RUN_SCRIPT:-""}
SSH_USER=${SSH_USER:-"root"}
SERVER_NAME=${SERVER_NAME:-""}

# List of env variables with values to pass to remote script
# Should be constructed as `${VAR_1@A} ${VAR_2@A}`
ENV_CONTEXT=${ENV_CONTEXT:-""}

if [[ -z "$RUN_SCRIPT" ]]
then
    echo "Please specify RUN_SCRIPT env variable"
    exit 1
fi

if [[ -z "$SERVER_NAME" ]]
then
    echo "Please specify SERVER_NAME env variable"
    exit 1
fi


# Get server ip

SERVER_IP=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_public_ip.sh $SERVER_NAME)



echo $ENV_CONTEXT | cat - "$RUN_SCRIPT" | ssh -oStrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" bash -x

