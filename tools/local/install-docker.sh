#!/bin/bash


sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg jq

if [[ ! -e /etc/apt/keyrings/docker.gpg ]]
then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

if [[ ! -e /etc/apt/sources.list.d/docker.list ]]
then
    cat <<-EOF | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable
    EOF
fi

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod "$USER" -aG docker
