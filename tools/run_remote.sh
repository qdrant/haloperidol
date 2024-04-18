#!/bin/bash

set -e
set -x

SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
CLOUD_NAME=${CLOUD_NAME:-"hetzner"}

BG_TASK_NAME=${BG_TASK_NAME:-""}

RUN_SCRIPT=${RUN_SCRIPT:-""}
SERVER_NAME=${SERVER_NAME:-""}

DEFAULT_SSH_USER=$(bash $SCRIPT_PATH/clouds/$CLOUD_NAME/get_ssh_user.sh $SERVER_NAME)

SSH_USER=${SSH_USER:-${DEFAULT_SSH_USER}}

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

if [ -z "$BG_TASK_NAME" ]; then
    echo "$ENV_CONTEXT" | cat - "$RUN_SCRIPT" | ssh -oStrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" sudo bash -x
else
    # Could directly cat inside screen instead of using scp but it's better to persist the script for debugging purposes
    scp -oStrictHostKeyChecking=no "$RUN_SCRIPT" "$SSH_USER@$SERVER_IP:/tmp/$BG_TASK_NAME.sh"
    ssh -oStrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "screen -X -S $BG_TASK_NAME quit || true" # Kill existing screen session

    ssh -oStrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "screen -dmS $BG_TASK_NAME"
    ssh -oStrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "screen -S $BG_TASK_NAME -X stuff '$ENV_CONTEXT'"
    ssh -oStrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "screen -S $BG_TASK_NAME -X stuff '$RUN_SCRIPT'"
fi
