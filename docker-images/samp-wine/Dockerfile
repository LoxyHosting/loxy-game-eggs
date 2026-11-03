FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PTERODACTYL_CONTAINER=1 \
    HOME=/home/container \
    WINEPREFIX=/home/container/.wine \
    WINEARCH=win32 \
    DISPLAY=:99

WORKDIR /home/container

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        file \
        git \
        gzip \
        iproute2 \
        locales \
        procps \
        psmisc \
        tzdata \
        unzip \
        wget \
        xz-utils \
        xvfb \
        winbind \
        wine32 \
        wine64 \
        cabextract \
        p7zip-full \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen \
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && mkdir -p /home/container /home/container/plugins /tmp/servers \
    && groupadd --gid 1000 container || true \
    && useradd --uid 1000 --gid 1000 --home-dir /home/container --shell /bin/bash container || true \
    && chown -R container:container /home/container /tmp/servers

USER container

EXPOSE 7777/udp 7778/udp 30120/udp

CMD ["bash"]
