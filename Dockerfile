ARG BUILD_FROM
FROM $BUILD_FROM

# Installer les dépendances nécessaires
RUN apk add --no-cache nodejs npm

# Créer le répertoire de travail
WORKDIR /opt/iobroker

# Installer ioBroker
RUN npm install iobroker --unsafe-perm

# Copier le script de démarrage
COPY run.sh /
RUN chmod a+x /run.sh

# Exposer le port
EXPOSE 8081

# Lancer le script de démarrage
CMD [ "/run.sh" ] 