#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Refusing to run the SA-MP server as root." >&2
  exit 1
fi

cd /home/container

if [ $# -gt 0 ]; then
  exec "$@"
fi

if [ -x /home/container/start.sh ]; then
  exec /home/container/start.sh
fi

exec /bin/bash
