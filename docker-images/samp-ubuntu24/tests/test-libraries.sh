#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${IMAGE_REF:-loxyhosting/samp-ubuntu24:latest}"

docker run --rm "${IMAGE_REF}" /bin/bash -lc '
  set -euo pipefail
  dpkg --print-architecture | grep -qx amd64
  dpkg --print-foreign-architectures | grep -qx i386
  dpkg -l
  ldconfig -p
  for library in \
    libc.so.6 \
    libstdc++.so.6 \
    libgcc_s.so.1 \
    libz.so.1 \
    libatomic.so.1 \
    libcurl.so.4 \
    libssl.so.3 \
    libnghttp2.so.14 \
    libidn2.so.0 \
    libpsl.so.5 \
    libssh2.so.1 \
    librtmp.so.1 \
    libmysqlclient.so.21 \
    libsqlite3.so.0 \
    libgomp.so.1 \
    libexpat.so.1 \
    libtinfo.so.6 \
    libncurses.so.6 \
    libuuid.so.1; do
    for architecture in "(libc6,x86-64)" "(libc6)"; do
      if ! ldconfig -p | grep -F "$library" | grep -Fq "$architecture"; then
        echo "Missing $library for $architecture." >&2
        exit 1
      fi
    done
    echo "OK $library (amd64, i386)"
  done
  for tool in file as ld patchelf ps curl wget unzip tar xz ss netstat dig lsof pgrep pkill nc; do
    command -v "$tool" >/dev/null
  done
  for package in libssl1.1 libgcc1 libmysqlclient18 libtinfo5 libncurses5; do
    if dpkg-query -s "$package" >/dev/null 2>&1; then
      echo "Legacy package installed: $package"
    else
      echo "Unavailable legacy package (Ubuntu 24.04): $package"
    fi
  done
'
