#!/usr/bin/with-contenv bashio

# Récupérer les options de configuration
PORT=$(bashio::config 'port')

# Démarrer ioBroker
cd /opt/iobroker
iobroker start

# Attendre que ioBroker soit prêt
while ! nc -z localhost 8081; do
  sleep 1
done

# Maintenir le conteneur en vie
tail -f /opt/iobroker/log/iobroker.log 