#!/usr/bin/env bash
set -euo pipefail

echo "[2/3] Verifying critical dynamic libraries"
ldconfig -p | grep -E 'libstdc\+\+|libgcc_s|libcurl|libssl|libmariadb|libmysqlclient|libsqlite3|zlib|libidn2|libssh2' >/dev/null

echo "Dynamic libraries detected successfully."

for lib in \
  libc6 \
  libstdc++6 \
  libssl3 \
  libcurl4 \
  libmariadb3 \
  libsqlite3-0; do
  if ! ldconfig -p | grep -q "$lib"; then
    echo "Missing library: $lib" >&2
    exit 1
  fi
done

printf '\nLibrary verification completed.\n'
