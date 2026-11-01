FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PTERODACTYL_CONTAINER=1 \
    HOME=/home/container \
    LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib32:/usr/lib32:/lib32:/opt/loxy-compat/lib:/opt/loxy-compat/lib32${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}} \
    SA_MP_COMPAT_PATH=/opt/loxy-compat \
    PLUGIN_PATH=/home/container/plugins

WORKDIR /home/container

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dnsutils \
        file \
        git \
        iproute2 \
        locales \
        lsof \
        net-tools \
        patchelf \
        procps \
        psmisc \
        tar \
        tzdata \
        unzip \
        wget \
        xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && locale-gen en_US.UTF-8 || true

RUN dpkg --add-architecture i386

COPY scripts/install-dependencies.sh /tmp/install-dependencies.sh
COPY scripts/compatibility-check.sh /tmp/compatibility-check.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /tmp/install-dependencies.sh /tmp/compatibility-check.sh /usr/local/bin/entrypoint.sh \
    && /tmp/install-dependencies.sh \
    && /tmp/compatibility-check.sh \
    && rm -f /tmp/install-dependencies.sh /tmp/compatibility-check.sh

RUN mkdir -p /opt/loxy-compat/lib /opt/loxy-compat/lib32 /home/container /home/container/plugins /tmp/servers /var/log/samp \
    && printf '%s\n' '/usr/local/lib' '/usr/local/lib32' '/usr/lib32' '/lib32' '/opt/loxy-compat/lib' '/opt/loxy-compat/lib32' > /etc/ld.so.conf.d/loxy-compat.conf \
    && ldconfig \
    && groupadd --gid 1000 container || true \
    && useradd --uid 1000 --gid 1000 --home-dir /home/container --shell /bin/bash container || true \
    && chown -R container:container /home/container /home/container/plugins /tmp/servers /var/log/samp /opt/loxy-compat

USER container

EXPOSE 7777/udp 7778/udp 30120/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
