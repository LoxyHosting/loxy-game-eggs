#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

# Enable 32-bit compatibility on an amd64 Ubuntu 24.04 base.
dpkg --add-architecture i386

apt-get update

apt-get install -y --no-install-recommends \
  bash \
  binutils \
  ca-certificates \
  curl \
  dnsutils \
  file \
  iproute2 \
  lsof \
  locales \
  net-tools \
  netcat-openbsd \
  patchelf \
  procps \
  psmisc \
  tar \
  tzdata \
  unzip \
  wget \
  xz-utils \
  libc6 \
  libc6:i386 \
  lib32gcc-s1 \
  lib32stdc++6 \
  lib32z1 \
  libstdc++6 \
  libstdc++6:i386 \
  libgcc-s1 \
  libgcc-s1:i386 \
  zlib1g \
  zlib1g:i386 \
  libatomic1 \
  libatomic1:i386 \
  libcurl4t64 \
  libcurl4t64:i386 \
  libssl3t64 \
  libssl3t64:i386 \
  libnghttp2-14 \
  libnghttp2-14:i386 \
  libidn2-0 \
  libidn2-0:i386 \
  libpsl5 \
  libpsl5:i386 \
  libssh2-1t64 \
  libssh2-1t64:i386 \
  librtmp1 \
  librtmp1:i386 \
  libmariadb3 \
  libmysqlclient21 \
  libmysqlclient21:i386 \
  libsqlite3-0 \
  libsqlite3-0:i386 \
  libgomp1 \
  libgomp1:i386 \
  libexpat1 \
  libexpat1:i386 \
  libtinfo6 \
  libtinfo6:i386 \
  libncurses6 \
  libncurses6:i386 \
  libuuid1 \
  libuuid1:i386 \
  libaio1t64 \
  libaio1t64:i386 \
  libdb5.3t64 \
  libdb5.3t64:i386 \
  libbz2-1.0 \
  libbz2-1.0:i386 \
  libfreetype6 \
  libfreetype6:i386 \
  libudev1 \
  libudev1:i386

# Keep a dedicated plugin-compat directory for old 32-bit plugins and private libs.
mkdir -p /opt/loxy-compat/lib /opt/loxy-compat/lib32

# Ubuntu 24.04 no longer provides libssl1.1, libgcc1, libmysqlclient18,
# libtinfo5, or libncurses5. Do not mix packages from another release.
rm -rf /var/lib/apt/lists/*

printf '%s\n' '/usr/local/lib' '/usr/local/lib32' '/usr/lib32' '/lib32' '/opt/loxy-compat/lib' '/opt/loxy-compat/lib32' > /etc/ld.so.conf.d/loxy-compat.conf
ldconfig
