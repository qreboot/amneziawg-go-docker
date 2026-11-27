# syntax=docker/dockerfile:1.7

FROM golang:1.25.8-alpine3.23 AS builder

# Версии upstream зафиксированы: содержимое образа определяется этими ARG,
# а не датой сборки. Обновлять версии — осознанно, bump'ом этих значений.
ARG AMNEZIAWG_GO_VERSION=v3.1.20260828
ARG AMNEZIAWG_TOOLS_VERSION=v3.1.20260812

RUN apk add --no-cache \
        bash \
        build-base \
        ca-certificates \
        git \
        linux-headers \
        libmnl-dev \
        pkgconf

WORKDIR /src

RUN git clone --depth 1 --branch "${AMNEZIAWG_GO_VERSION}" https://github.com/amnezia-vpn/amneziawg-go.git && \
    git clone --depth 1 --branch "${AMNEZIAWG_TOOLS_VERSION}" https://github.com/amnezia-vpn/amneziawg-tools.git

RUN cd /src/amneziawg-go && \
    make -j"$(nproc)" && \
    mkdir -p /out/usr/local/bin && \
    cp amneziawg-go /out/usr/local/bin/amneziawg-go && \
    chmod +x /out/usr/local/bin/amneziawg-go

RUN cd /src/amneziawg-tools/src && \
    make -j"$(nproc)" && \
    install -Dm755 wg /out/usr/bin/awg && \
    install -Dm755 wg-quick/linux.bash /out/usr/bin/awg-quick

FROM alpine:3.23.3

COPY entrypoint.sh /entrypoint.sh
COPY --from=builder /out/ /

RUN apk add --no-cache \
        bash \
        ca-certificates \
        iproute2 \
        iptables \
        libmnl && \
    mkdir -p /etc/amnezia/amneziawg && \
    chmod +x /entrypoint.sh

WORKDIR /etc/amnezia

ENTRYPOINT ["/entrypoint.sh"]