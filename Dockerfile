ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bullseye
FROM ${BUILD_FROM}

ENV LANG C.UTF-8

# Installation des dépendances
RUN apt-get update && apt-get install -y \
    curl \
    bash \
    jq \
    nodejs \
    npm \
    build-essential \
    git \
    acl \
    sudo \
    libavahi-compat-libdnssd-dev \
    libudev-dev \
    libpam0g-dev \
    pkg-config \
    unzip \
    net-tools \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    libpixman-1-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copie des scripts et des fichiers de configuration
COPY rootfs /

# Exécution des scripts
RUN chmod a+x /etc/s6-overlay/s6-rc.d/*/run \
    && chmod a+x /etc/s6-overlay/scripts/*.sh

# Création de l'utilisateur iobroker
RUN useradd -m iobroker \
    && adduser iobroker sudo \
    && echo "iobroker ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/iobroker \
    && chmod 0440 /etc/sudoers.d/iobroker

# Configuration de l'autostart
WORKDIR /opt/iobroker

CMD [ "/init" ] 