ARG BUILD_FROM
FROM $BUILD_FROM

# Installer les dépendances nécessaires
RUN apk add --no-cache \
    bash \
    nodejs \
    npm \
    curl \
    jq \
    sudo \
    git \
    make \
    g++ \
    python3 \
    py3-pip \
    setcap \
    libcap \
    linux-headers \
    procps \
    net-tools \
    nano \
    shadow \
    openssl

# Créer l'utilisateur iobroker
RUN addgroup -S iobroker && \
    adduser -S -D -h /opt/iobroker -s /bin/bash -G iobroker iobroker && \
    mkdir -p /opt/iobroker && \
    chown -R iobroker:iobroker /opt/iobroker && \
    echo "iobroker ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Copier les fichiers
COPY rootfs /
COPY install.sh /tmp/install.sh

# Rendre les scripts exécutables
RUN chmod a+x /etc/services.d/iobroker/run /etc/services.d/iobroker/finish /etc/cont-init.d/* /etc/services.d/iobroker/type

# Configuration de l'environnement
ENV HOME="/root"
ENV NODE_ENV="production"

# Exposer les ports utilisés par ioBroker
EXPOSE 8081 8082 8083 8084 8085 9000/udp 8087

# Étiquettes
LABEL \
    io.hass.name="ioBroker" \
    io.hass.description="ioBroker pour Home Assistant" \
    io.hass.version="1.0.2" \
    io.hass.type="addon" \
    io.hass.arch="armhf|aarch64|i386|amd64"

# Démarrer l'application
CMD [ "/usr/bin/bashio" ] 