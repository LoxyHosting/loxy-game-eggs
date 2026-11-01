#!/usr/bin/env bash
set -euo pipefail

echo "== Architecture =="
test "$(dpkg --print-architecture)" = amd64
dpkg --print-architecture
dpkg --print-foreign-architectures | grep -qx i386
dpkg --print-foreign-architectures

echo "== Dynamic libraries by architecture =="
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
  for architecture in '(libc6,x86-64)' '(libc6)'; do
    if ! ldconfig -p | grep -F "$library" | grep -Fq "$architecture"; then
      echo "Missing ${library} for ${architecture}." >&2
      exit 1
    fi
  done
  echo "OK $library (amd64, i386)"
done

if ldconfig -p | grep -F 'libmariadb.so.3' | grep -Fq '(libc6,x86-64)'; then
  echo "OK libmariadb.so.3 (amd64; no Noble i386 package)"
fi

echo "== Plugin compatibility directories =="
for dir in /opt/loxy-compat/lib /opt/loxy-compat/lib32 /usr/lib32 /lib32; do
  test -d "$dir"
  echo "OK $dir"
done

echo "== Legacy packages unavailable in Ubuntu 24.04 =="
for package in libssl1.1 libgcc1 libmysqlclient18 libtinfo5 libncurses5; do
  if dpkg-query -s "$package" >/dev/null 2>&1; then
    echo "PRESENT $package"
  else
    echo "UNAVAILABLE $package"
  fi
done
