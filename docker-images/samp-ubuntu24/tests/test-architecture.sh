#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] Verifying architectures"
if ! dpkg --print-foreign-architectures | grep -q i386; then
  echo "i386 architecture was not enabled." >&2
  exit 1
fi

file /bin/bash
file /usr/bin/env

printf '\nArchitecture verification completed.\n'
