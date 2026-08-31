# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bc \
        binutils-aarch64-linux-gnu \
        bison \
        build-essential \
        ca-certificates \
        cpio \
        device-tree-compiler \
        dosfstools \
        e2fsprogs \
        file \
        flex \
        gawk \
        gcc-aarch64-linux-gnu \
        git \
        gzip \
        jq \
        kmod \
        libelf-dev \
        libncurses-dev \
        libssl-dev \
        lz4 \
        make \
        mtools \
        openssh-client \
        patch \
        perl \
        python3 \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        rsync \
        shellcheck \
        swig \
        tar \
        u-boot-tools \
        unzip \
        uuid-runtime \
        wget \
        xz-utils \
        zstd \
    && rm -rf /var/lib/apt/lists/*

ENV ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    TZ=UTC \
    SOURCE_DATE_EPOCH=0

WORKDIR /workspace
