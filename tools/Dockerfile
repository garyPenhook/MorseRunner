FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        fpc \
        lazarus \
        lcl \
        lcl-gtk3 \
        lcl-units \
        lcl-utils \
        make \
        pkg-config \
        portaudio19-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
