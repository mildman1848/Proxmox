#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: community-scripts ORG
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://www.audiobookshelf.org/

APP="Alpine-Audiobookshelf"
var_tags="${var_tags:-alpine;podcast;audiobook}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-5}"
var_os="${var_os:-alpine}"
var_version="${var_version:-auto}"
var_unprivileged="${var_unprivileged:-1}"

# Auto-select latest available Alpine version for host arch
if [ "$var_version" = "auto" ]; then
  if command -v dpkg >/dev/null 2>&1; then
    host_arch="$(dpkg --print-architecture)"
  else
    host_arch="$(uname -m)"
  fi

  case "$host_arch" in
    amd64|x86_64) pve_arch="system" ;;
    arm64|aarch64) pve_arch="arm64" ;;
    *) pve_arch="system" ;;
  esac

  latest_alpine_version="$(
    pveam available 2>/dev/null \
      | awk -v arch="$pve_arch" '$1==arch && $2 ~ /^alpine-[0-9]/ {print $2}' \
      | sed -E 's/^alpine-([0-9]+\.[0-9]+).*/\1/' \
      | sort -V \
      | tail -n1
  )"

  latest_local_version="$(
    ls -1 /var/lib/vz/template/cache 2>/dev/null \
      | sed -nE 's/^alpine-([0-9]+\.[0-9]+).*/\1/p' \
      | sort -V \
      | tail -n1
  )"

  if [ -n "$latest_local_version" ] && [ -n "$latest_alpine_version" ]; then
    var_version="$(printf '%s\n%s\n' "$latest_alpine_version" "$latest_local_version" | sort -V | tail -n1)"
  elif [ -n "$latest_local_version" ]; then
    var_version="$latest_local_version"
  elif [ -n "$latest_alpine_version" ]; then
    var_version="$latest_alpine_version"
  else
    var_version="3.23"
  fi
fi

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  if [ ! -d /opt/audiobookshelf ]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating Alpine Packages"
  $STD apk -U upgrade
  msg_ok "Updated Alpine Packages"

  msg_info "Updating Audiobookshelf"
  $STD su -s /bin/sh audiobookshelf -c "export HOME=/tmp; cd /opt/audiobookshelf && git pull"
  $STD su -s /bin/sh audiobookshelf -c "export HOME=/tmp; cd /opt/audiobookshelf; if npm install --help 2>/dev/null | grep -q -- '--omit'; then npm install --omit=dev; elif npm install --help 2>/dev/null | grep -q -- '--production'; then npm install --production; else npm install; fi"
  $STD su -s /bin/sh audiobookshelf -c "export HOME=/tmp; cd /opt/audiobookshelf/client && npm ci"
  $STD su -s /bin/sh audiobookshelf -c "export HOME=/tmp; cd /opt/audiobookshelf/client && npm run generate"
  $STD rc-service audiobookshelf restart
  msg_ok "Updated Audiobookshelf"
  msg_ok "Updated successfully!"
  exit 0
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:13378${CL}"
