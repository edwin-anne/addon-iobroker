#!/usr/bin/with-contenv bashio

echo "Démarrage de ioBroker..."

# Installer ioBroker dans le répertoire de données
cd /data
npm install iobroker --unsafe-perm

# Démarrer ioBroker
iobroker start

# Attendre que ioBroker soit prêt
while ! nc -z localhost 8081; do
  echo "En attente du démarrage de ioBroker..."
  sleep 1
done

echo "ioBroker est démarré et accessible sur le port 8081"

# Maintenir le conteneur en vie et afficher les logs
tail -f /data/iobroker/log/iobroker.log 