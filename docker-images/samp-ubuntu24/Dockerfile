FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PTERODACTYL_CONTAINER=1 \
    HOME=/home/container \
    LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib32:/usr/lib32:/lib32:/opt/loxy-compat/lib:/opt/loxy-compat/lib32 \
    SA_MP_COMPAT_PATH=/opt/loxy-compat \
    PLUGIN_PATH=/home/container/plugins

WORKDIR /home/container

COPY scripts/install-dependencies.sh /tmp/install-dependencies.sh
COPY scripts/compatibility-check.sh /tmp/compatibility-check.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN set -eux; \
    chmod +x /tmp/install-dependencies.sh /tmp/compatibility-check.sh /usr/local/bin/entrypoint.sh; \
    /tmp/install-dependencies.sh; \
    /tmp/compatibility-check.sh; \
    rm -f /tmp/install-dependencies.sh /tmp/compatibility-check.sh; \
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime; \
    printf '%s\n' "${TZ}" > /etc/timezone; \
    locale-gen en_US.UTF-8

RUN set -eux; \
    mkdir -p /home/container/plugins /tmp/servers /var/log/samp; \
    if ! getent group container >/dev/null; then groupadd container; fi; \
    if ! getent passwd container >/dev/null; then useradd --create-home --home-dir /home/container --gid container --shell /bin/bash container; fi; \
    chown -R container:container /home/container /tmp/servers /var/log/samp /opt/loxy-compat

USER container

EXPOSE 7777/udp 7778/udp 30120/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
