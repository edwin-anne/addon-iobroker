ARG BUILD_FROM
FROM $BUILD_FROM

# Installer les dépendances nécessaires
RUN apk add --no-cache bash nodejs npm curl jq sudo git make g++ python3 setcap libcap linux-headers

# Créer l'utilisateur iobroker
RUN addgroup -S iobroker && \
    adduser -S -D -H -h /opt/iobroker -s /bin/bash -G iobroker iobroker && \
    mkdir -p /opt/iobroker && \
    chown -R iobroker:iobroker /opt/iobroker

# Copier les fichiers
COPY rootfs /
COPY install.sh /tmp/install.sh

# Rendre les scripts exécutables
RUN chmod a+x /etc/services.d/iobroker/run /etc/services.d/iobroker/finish /etc/cont-init.d/*

# Configuration de l'environnement
ENV HOME="/root"

# Exposer les ports utilisés par ioBroker
EXPOSE 8081 8082 8083 8084 8085 9000/udp 8087

# Étiquettes
LABEL \
    io.hass.name="ioBroker" \
    io.hass.description="ioBroker pour Home Assistant" \
    io.hass.version="1.0.0" \
    io.hass.type="addon" \
    io.hass.arch="armhf|aarch64|i386|amd64"

# Démarrer l'application
CMD [ "/usr/bin/bashio" ] 