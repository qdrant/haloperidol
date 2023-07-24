#!/usr/bin/env bash

set -euo pipefail


function self {
	realpath "$0" 2>/dev/null || which "$0" 2>/dev/null
	return "$?"
}


declare SELF="$(self)"

declare CI="${CI:-$(dirname "$SELF")}"
declare LOCAL="${LOCAL:-$(dirname "$CI")/local}"

declare INSTALL_DOCKER="${INSTALL_DOCKER:-$LOCAL/install-docker.sh}"


declare BASE_NAME="${BASE_NAME:-qdrant-stress-testing}"

declare GROUP="${GROUP:-$BASE_NAME}"
declare LOCATION="${LOCATION:-westeurope}"

declare VNET="${VNET:-$BASE_NAME-vnet}"
declare VNET_NETMASK="${VNET_NETMASK:-10.0.0.0/16}"

declare SUBNET="${SUBNET:-$BASE_NAME-subnet}"
declare SUBNET_NETMASK="${SUBNET_NETMASK:-10.0.0.0/24}"

declare QDRANT_NODE_NAME="${QDRANT_NODE_NAME:-$BASE_NAME}"
declare BFB_NODE_NAME="${QDRANT_NODE_NAME:-$BASE_NAME-bfb}"

declare VM_SIZE="${VM_SIZE:-Standard_DS1_v2}"
declare VM_IMAGE="${VM_IMAGE:-Ubuntu2204}"
declare VM_USER="${VM_USER:-qdrant}"


function bootstrap-stress-testing-nodes {
	create-resource-group
	create-virtual-network

	declare -a QDRANT_NODES
	bootstrap-qdrant-nodes 3
	bootstrap-bfb-nodes 1 ${QDRANT_NODES[@]/#/--uri } # NOTE: Unescaped parameter expansion
}

function bootstrap-qdrant-nodes {
	declare NODES="$1"

	declare BOOTSTRAP=()

	for NODE in $(nodes "$QDRANT_NODE_NAME" "$NODES") # NOTE: Unescaped command substitution
	do
		create-virtual-machine "$NODE"

		declare VM_ADDR; VM_ADDR="$(get-virtual-machine-public-ip "$NODE")"
		declare VM_PRIV_ADDR; VM_PRIV_ADDR="$(get-virtual-machine-private-ip "$NODE")"

		install-docker "$VM_ADDR"
		run-remote-qdrant-node "$VM_ADDR" --uri "http://$VM_PRIV_ADDR:6335" "${BOOTSTRAP[@]}"

		if [[ ! ${BOOTSTRAP-} ]]
		then
			BOOTSTRAP=( --bootstrap "http://$VM_PRIV_ADDR:6335" )
		fi

		if declare -p -a QDRANT_NODES &>/dev/null
		then
			QDRANT_NODES+=( "$VM_PRIV_ADDR" )
		fi
	done
}

function run-remote-qdrant-node {
	declare VM_ADDR="$1"
	remote-run "$VM_ADDR" run-qdrant-node "${@:2}"
}

function run-qdrant-node {
	declare VM_PRIV_ADDR="$1"
	- docker run \
		-d \
		-p "$VM_PRIV_ADDR":6333:6333 \
		-p "$VM_PRIV_ADDR":6334:6334 \
		-p "$VM_PRIV_ADDR":6335:6335 \
		-e QDRANT__CLUSTER__ENABLE=true \
		qdrant/qdrant \
		./qdrant "${@:2}"
}

function bootstrap-bfb-nodes {
	declare NODES="$1"

	if (( $# < 3 ))
	then
		echo "ERROR: Not enough arguments! 'bootstrap-bfb-nodes' expects '--uri <QDRANT NODE ADDRESS>' arguments!" >&2
		return 1
	fi

	for NODE in $(nodes "$BFB_NODE_NAME" "$NODES") # NOTE: Unescaped command substitution
	do
		create-virtual-machine "$NODE"

		declare VM_ADDR; VM_ADDR="$(get-virtual-machine-public-ip "$NODE")"

		install-docker "$VM_ADDR"
		run-remote-bfb-node "$VM_ADDR" "${@:2}"
	done
}

function run-remote-bfb-node {
	declare VM_ADDR="$1"
	remote-run "$VM_ADDR" run-bfb-node "${@:2}"
}

function run-bfb-node {
	- docker run \
		-d \
		--network host \
		qdrant/bfb \
		bash -c "while ./bfb ${@@Q}; do :; done"
}


function nodes {
	declare NAME="$1"
	declare NODES="${2:-1}"

	if (( NODES > 1 ))
	then
		for IDX in $(seq "$NODES")
		do
			echo "$NAME-$IDX"
		done
	else
		echo "$NAME"
	fi
}

function install-docker {
	declare VM_ADDR="$1"

	if [[ ! ${ECHO-} ]]
	then
		cat "$INSTALL_DOCKER" | ssh "$VM_USER@$VM_ADDR" -- bash -s "${@:2}"
	else
		echo "cat $INSTALL_DOCKER | ssh $VM_USER@$VM_ADDR -- bash -s ${@:2}" >&2
	fi
}


function create-resource-group {
	declare GROUP="${1:-$GROUP}"
	declare LOCATION="${2:-$LOCATION}"

	- az group create --name "$GROUP" --location "$LOCATION"
}

function create-virtual-network {
	declare VNET="${1:-$VNET}"
	declare VNET_NETMASK="${2:-$VNET_NETMASK}"

	declare SUBNET="${3:-$SUBNET}"
	declare SUBNET_NETMASK="${4:-$SUBNET_NETMASK}"

	- az network vnet create \
		--resource-group "$GROUP" \
		--name "$VNET" \
		--address-prefixes "$VNET_NETMASK" \
		--subnet-name "$SUBNET" \
		--subnet-prefixes "$SUBNET_NETMASK"
}

function create-virtual-machine {
	declare VM_NAME="$1"

	- az vm create \
		--resource-group "$GROUP" \
		--name "$VM_NAME" \
		--size "$VM_SIZE" \
		--image "$VM_IMAGE" \
		--admin-username "$VM_USER" \
		--vnet-name "$VNET" \
		--subnet "$SUBNET" \
		--public-ip-sku Standard \
		--os-disk-delete-option delete \
		--data-disk-delete-option delete \
		--nic-delete-option delete \
		--generate-ssh-keys \
		--verbose \
		"${@:2}"
}

function get-virtual-machine-public-ip {
	get-virtual-machine-ip "$@" \
		--output tsv \
		--query '[].virtualMachine.network.publicIpAddresses[0].ipAddress'
}

function get-virtual-machine-private-ip {
	get-virtual-machine-ip "$@" \
		--output tsv \
		--query '[].virtualMachine.network.privateIpAddresses[0]'
}

function get-virtual-machine-ip {
	declare VM_NAME="$1"

	- az vm list-ip-addresses --resource-group "$GROUP" --name "$VM_NAME" "${@:2}"
	-- 0.0.0.0
}

function remote-run {
	declare VM_ADDR="$1"

	if [[ ! ${ECHO-} ]]
	then
		echo REMOTE=1 | cat - "$SELF" | ssh "$VM_USER@$VM_ADDR" -- bash -s "${@:2}"
	else
		echo "echo REMOTE=1 | cat - $SELF | ssh $VM_USER@$VM_ADDR -- bash -s ${@:2}" >&2
	fi
}


function login {
	declare AZ_USER="${1-}"
	declare AZ_PASSWORD="${2-}"

	- az login ${AZ_USER:+--username} ${AZ_USER-} ${AZ_PASSWORD:+--password} ${AZ_PASSWORD-}
}

function list-locations {
	- az account list-locations --output table
}

function list-vm-sizes {
	- az vm list-sizes --location "$LOCATION" --output table
}

function list-vm-images {
	- az vm image list --output table
}


function init {
	if which az &>/dev/null
	then
		"$@"
	else
		dockerize "$@"
	fi
}

function dockerize {
	if [[ ${ECHO-} || ${DOCKERIZED-} || ${REMOTE-} ]]
	then
		"$@"
	else
		declare SELF_NAME="$(basename "$SELF")"

		- docker run --rm -it \
			-v "$SELF":/bin/"$SELF_NAME" \
			-v "$HOME"/.azure:/root/.azure \
			-v "$HOME"/.azure/ssh:/root/.ssh \
			-e DOCKERIZED=1 \
			mcr.microsoft.com/azure-cli \
			bash "${@:+$SELF_NAME}" "$@"
	fi
}

function - {
	if [[ ${ECHO-} ]]
	then
		echo "$@" >&2
	else
		"$@"
	fi
}

function -- {
	declare STATUS="$?"

	if [[ ${ECHO-} ]]
	then
		if (( $# ))
		then
			echo "$@"
		else
			cat
		fi
	else
		return "$STATUS"
	fi
}


if !(return 0 &>/dev/null)
then
	init "$@"
fi
