#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: community-scripts ORG
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://www.audiobookshelf.org/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

APPLICATION="${APPLICATION:-Audiobookshelf}"
SSH_ROOT="${SSH_ROOT:-no}"
PASSWORD="${PASSWORD:-}"

NUSQLITE3_DIR="/usr/local/lib/nusqlite3"
NUSQLITE3_PATH="${NUSQLITE3_DIR}/libnusqlite3.so"

msg_info "Installing Dependencies"
$STD apk add --no-cache \
  curl \
  ffmpeg \
  git \
  g++ \
  make \
  nodejs \
  npm \
  python3 \
  tini \
  tzdata \
  unzip
msg_ok "Installed Dependencies"

msg_info "Downloading Audiobookshelf"
$STD git clone https://github.com/advplyr/audiobookshelf /opt/audiobookshelf
msg_ok "Downloaded Audiobookshelf"

msg_info "Creating Audiobookshelf User"
adduser -D -H -s /sbin/nologin -G users audiobookshelf
msg_ok "Created Audiobookshelf User"

msg_info "Installing nusqlite3"
mkdir -p "$NUSQLITE3_DIR"
arch="$(uname -m)"
case "$arch" in
  x86_64)
    lib_url="https://github.com/mikiher/nunicode-sqlite/releases/download/v1.2/libnusqlite3-linux-musl-x64.zip"
    ;;
  aarch64)
    lib_url="https://github.com/mikiher/nunicode-sqlite/releases/download/v1.2/libnusqlite3-linux-musl-arm64.zip"
    ;;
  *)
    msg_error "Unsupported architecture: $arch"
    exit 1
    ;;
esac
$STD curl -L -o /tmp/library.zip "$lib_url"
$STD unzip /tmp/library.zip -d "$NUSQLITE3_DIR"
rm -f /tmp/library.zip
msg_ok "Installed nusqlite3"

msg_info "Building Audiobookshelf"
cd /opt/audiobookshelf
if npm install --help 2>/dev/null | grep -q -- '--omit'; then
  $STD npm install --omit=dev
elif npm install --help 2>/dev/null | grep -q -- '--production'; then
  $STD npm install --production
else
  $STD npm install
fi
cd client
$STD npm ci
$STD npm run generate
msg_ok "Built Audiobookshelf"

msg_info "Creating data directories"
mkdir -p /usr/share/audiobookshelf/config /usr/share/audiobookshelf/metadata
chown -R audiobookshelf:users /opt/audiobookshelf /usr/share/audiobookshelf
msg_ok "Created data directories"

msg_info "Creating Audiobookshelf Service"
mkdir -p /var/log
touch /var/log/audiobookshelf.log /var/log/audiobookshelf.err.log
chown audiobookshelf:users /var/log/audiobookshelf.log /var/log/audiobookshelf.err.log

cat <<'EOF' >/usr/local/bin/audiobookshelf
#!/usr/bin/env sh
export PORT=13378
export NODE_ENV=production
export CONFIG_PATH="/usr/share/audiobookshelf/config"
export METADATA_PATH="/usr/share/audiobookshelf/metadata"
export SOURCE="docker"
export NUSQLITE3_DIR="/usr/local/lib/nusqlite3"
export NUSQLITE3_PATH="/usr/local/lib/nusqlite3/libnusqlite3.so"
exec /usr/bin/node /opt/audiobookshelf/index.js >>/var/log/audiobookshelf.log 2>>/var/log/audiobookshelf.err.log
EOF
chmod +x /usr/local/bin/audiobookshelf

cat <<'EOF' >/etc/init.d/audiobookshelf
#!/sbin/openrc-run
description="Audiobookshelf Service"

command="/usr/local/bin/audiobookshelf"
command_background="yes"
pidfile="/run/audiobookshelf.pid"
command_user="audiobookshelf"

depend() {
  use net
}
EOF
chmod +x /etc/init.d/audiobookshelf
$STD rc-update add audiobookshelf default
$STD rc-service audiobookshelf start

msg_info "Running Health Check"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  status="$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:13378/ || true)"
  if [ "$status" -ge 200 ] && [ "$status" -lt 400 ]; then
    msg_ok "Audiobookshelf is responding on port 13378"
    break
  fi
  sleep 2
done

if [ "$status" -lt 200 ] || [ "$status" -ge 400 ]; then
  msg_error "Health check failed. Recent logs:"
  tail -n 50 /var/log/audiobookshelf.log || true
  tail -n 50 /var/log/audiobookshelf.err.log || true
  exit 1
fi

msg_ok "Started Audiobookshelf"

motd_ssh
customize
