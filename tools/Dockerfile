# Debian 11 carries glibc 2.31. Building release artifacts here establishes a
# materially older runtime baseline than the developer host while retaining a
# maintained FPC 3.2 toolchain.
FROM debian:bullseye-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        build-essential \
        curl \
        file \
        fpc \
        git \
        make \
        desktop-file-utils \
        dpkg-dev \
        pkg-config \
        libgtk-3-dev \
        libpulse-dev \
        portaudio19-dev \
        patch \
        xvfb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
