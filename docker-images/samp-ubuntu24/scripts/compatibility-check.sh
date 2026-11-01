#!/usr/bin/env bash
set -uo pipefail

echo "== Architecture =="
dpkg --print-architecture
dpkg --print-foreign-architectures || true

echo "== ldconfig libraries =="
ldconfig -p | grep -E 'libstdc\+\+|libgcc_s|libcurl|libssl|libmysql|libmariadb|libsqlite|zlib|libidn2|libnghttp2|libssh2|libpsl|libxml2|libfreetype' || true

echo "== Critical packages =="
for pkg in \
  libc6 \
  libc6:i386 \
  lib32gcc-s1 \
  lib32stdc++6 \
  libstdc++6 \
  libstdc++6:i386 \
  libgcc-s1 \
  libgcc-s1:i386 \
  zlib1g \
  zlib1g:i386 \
  libcurl4 \
  libcurl4:i386 \
  libssl3 \
  libssl3:i386 \
  libmariadb3 \
  libmariadb3:i386 \
  libsqlite3-0 \
  libsqlite3-0:i386; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "OK $pkg"
  else
    echo "MISSING $pkg"
  fi
done

echo "== Plugin compatibility directories =="
for dir in /opt/loxy-compat/lib /opt/loxy-compat/lib32 /usr/lib32 /lib32; do
  if [ -d "$dir" ]; then
    echo "OK $dir"
  else
    echo "MISSING $dir"
  fi
done

echo "== Legacy runtime warnings =="
for pkg in libssl1.1:i386 libgcc1:i386 libmysqlclient18:i386; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "LEGACY PRESENT $pkg"
  else
    echo "UNAVAILABLE in Ubuntu 24.04 (compatibility isolated via /opt/loxy-compat): $pkg"
  fi
done

echo "== Compatibility check complete =="
