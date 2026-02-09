#!/usr/bin/env bash

# Copyright (c) 2021-2026 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://www.docker.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apk add tzdata
msg_ok "Installed Dependencies"

msg_info "Installing Docker"
$STD apk add docker
$STD rc-service docker start
$STD rc-update add docker default
msg_ok "Installed Docker"

get_latest_release() {
  curl -fsSL https://api.github.com/repos/"$1"/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}
PORTAINER_LATEST_VERSION=$(get_latest_release "portainer/portainer")
DOCKER_COMPOSE_LATEST_VERSION=$(get_latest_release "docker/compose")
PORTAINER_AGENT_LATEST_VERSION=$(get_latest_release "portainer/agent")

prompt="n"
if [ -t 0 ]; then
  read -r -p "${TAB3}Would you like to add Portainer? <y/N> " prompt
fi
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
  msg_info "Installing Portainer $PORTAINER_LATEST_VERSION"
  docker volume create portainer_data >/dev/null
  $STD docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name=portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
  msg_ok "Installed Portainer $PORTAINER_LATEST_VERSION"
else
  prompt="n"
  if [ -t 0 ]; then
    read -r -p "${TAB3}Would you like to add the Portainer Agent? <y/N> " prompt
  fi
  if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
    msg_info "Installing Portainer agent $PORTAINER_AGENT_LATEST_VERSION"
    $STD docker run -d \
      -p 9001:9001 \
      --name portainer_agent \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /var/lib/docker/volumes:/var/lib/docker/volumes \
      portainer/agent
    msg_ok "Installed Portainer Agent $PORTAINER_AGENT_LATEST_VERSION"
  fi
fi
prompt="n"
if [ -t 0 ]; then
  read -r -p "${TAB3}Would you like to add Docker Compose? <y/N> " prompt
fi
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
  msg_info "Installing Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"
  DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
  mkdir -p "$DOCKER_CONFIG"/cli-plugins
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) compose_arch="x86_64" ;;
    aarch64|arm64) compose_arch="aarch64" ;;
    armv7l|armhf) compose_arch="armv7" ;;
    *) msg_error "Unsupported architecture: $arch" && exit 1 ;;
  esac
  curl -fsSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_LATEST_VERSION}/docker-compose-linux-${compose_arch}" -o ~/.docker/cli-plugins/docker-compose
  chmod +x "$DOCKER_CONFIG"/cli-plugins/docker-compose
  msg_ok "Installed Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"
fi

prompt="n"
if [ -t 0 ]; then
  read -r -p "${TAB3}Would you like to expose the Docker TCP socket? <y/N> " prompt
fi
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
  msg_info "Exposing Docker TCP socket"
  $STD mkdir -p /etc/docker
  $STD echo '{ "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"] }' > /etc/docker/daemon.json
  $STD rc-service docker restart
  msg_ok "Exposed Docker TCP socket at tcp://+:2375"
fi

motd_ssh
customize
