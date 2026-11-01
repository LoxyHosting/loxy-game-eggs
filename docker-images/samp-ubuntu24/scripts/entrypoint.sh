#!/usr/bin/env bash
set -euo pipefail

if [ -n "${HOME:-}" ] && [ ! -d "$HOME" ]; then
  mkdir -p "$HOME"
fi

mkdir -p /opt/loxy-compat/lib /opt/loxy-compat/lib32 /home/container /home/container/plugins /tmp/servers /var/log/samp
printf '%s\n' '/usr/local/lib' '/usr/local/lib32' '/usr/lib32' '/lib32' '/opt/loxy-compat/lib' '/opt/loxy-compat/lib32' > /etc/ld.so.conf.d/loxy-compat.conf
ldconfig 2>/dev/null || true

if [ -d /home/container ]; then
  cd /home/container
fi

if [ "$EUID" -eq 0 ] && id container >/dev/null 2>&1; then
  chown -R container:container /home/container /home/container/plugins /tmp/servers /var/log/samp /opt/loxy-compat 2>/dev/null || true
fi

if [ $# -gt 0 ]; then
  exec "$@"
fi

if [ -x /home/container/start.sh ]; then
  exec /home/container/start.sh
fi

exec /bin/bash
