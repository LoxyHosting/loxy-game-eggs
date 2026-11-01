#!/usr/bin/env bash
set -euo pipefail

echo "[3/3] Verifying Pterodactyl compatibility assumptions"

for path in /home/container /tmp/servers /var/log/samp; do
  if [ ! -d "$path" ]; then
    echo "Required path missing: $path" >&2
    exit 1
  fi
done

printf '\nPterodactyl compatibility checks completed.\n'
