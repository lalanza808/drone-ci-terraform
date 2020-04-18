#!/bin/bash

# Drone CI Runner setup

set -x

export DEBIAN_FRONTEND=noninteractive
apt update

# Docker install
apt-get remove docker docker-engine docker.io containerd runc -y
apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io docker-compose -y
systemctl enable docker
systemctl start docker

docker run -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e DRONE_RPC_PROTO=${DRONE_RPC_PROTO} \
  -e DRONE_RPC_HOST=${DRONE_RPC_HOST} \
  -e DRONE_RPC_SECRET=${DRONE_RPC_SECRET} \
  -e DRONE_RUNNER_CAPACITY=${DRONE_RUNNER_CAPACITY} \
  -e DRONE_RUNNER_NAME=${DRONE_RUNNER_NAME} \
  -p 3000:3000 \
  --restart always \
  --name runner \
  drone/drone-runner-docker:1
