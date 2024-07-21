# Ubuntu Docker image
ARG BASE_IMAGE=ubuntu:20.04

FROM ${BASE_IMAGE}

# Install system dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
	lsb-release \
    build-essential \
    fakeroot \
    libncurses-dev \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    openssl \
    dkms \
    libudev-dev \
    libpci-dev \
    libiberty-dev \autoconf \
    wget \
    xz-utils git \
    libcap-dev \
    bc \
    rsync \
    cpio \
    dh-modaliases \
    debhelper \
    kernel-wedge \
    curl \
    gawk \
    dwarves \
    zstd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /repository

# Run
CMD [ "/bin/bash", "./build.sh"]