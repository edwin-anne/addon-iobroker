#!/usr/bin/with-contenv bash

# Script d'initialisation pour ioBroker
echo "Initialisation d'ioBroker..."

# Création du répertoire d'installation si nécessaire
mkdir -p /opt/iobroker
chown -R iobroker:iobroker /opt/iobroker

# Création du répertoire de données si nécessaire
DATA_DIR=/data/iobroker
mkdir -p ${DATA_DIR}
chown -R iobroker:iobroker ${DATA_DIR}

# Si nous utilisons un volume persistant pour les données
if [ ! -d "/opt/iobroker/iobroker-data" ]; then
    ln -s ${DATA_DIR} /opt/iobroker/iobroker-data
fi

# Préparation de l'environnement réseau (nécessaire pour certains adaptateurs ioBroker)
echo "Préparation de l'environnement réseau..."
if [ -x "$(command -v setcap)" ]; then
    setcap 'cap_net_admin,cap_net_bind_service,cap_net_raw+eip' $(eval readlink -f $(command -v node))
fi

# Vérification de la configuration réseau
echo "Configuration réseau:"
ip addr show
echo "Routes:"
ip route
echo "Vérification de la résolution de noms:"
cat /etc/hosts
cat /etc/resolv.conf

echo "Initialisation terminée." 