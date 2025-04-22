#!/usr/bin/with-contenv bashio

echo "Hello world!"

# Installer ioBroker
npm install iobroker --unsafe-perm

# Démarrer ioBroker
iobroker start

# Attendre que ioBroker soit prêt
while ! nc -z localhost 8081; do
  sleep 1
done

# Maintenir le conteneur en vie
tail -f /opt/iobroker/log/iobroker.log 