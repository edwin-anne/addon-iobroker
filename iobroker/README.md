# Module complémentaire ioBroker pour Home Assistant

Ce module complémentaire permet d'installer et d'exécuter ioBroker dans Home Assistant OS.

## À propos d'ioBroker

ioBroker est une plateforme de domotique open source qui permet d'intégrer divers systèmes et dispositifs IoT. Il offre un grand nombre d'adaptateurs pour communiquer avec différents appareils et services.

## Installation

1. Ajoutez ce référentiel à vos référentiels d'additionnels dans Home Assistant.
2. Installez le module complémentaire "ioBroker" depuis la liste des modules disponibles.
3. Configurez les options selon vos besoins.
4. Démarrez le module complémentaire.

## Interface utilisateur

Après le démarrage, l'interface d'administration d'ioBroker sera accessible via:

- L'onglet ioBroker dans le tableau de bord de Home Assistant
- Directement à l'adresse: `http://your-ha-ip:8081`

## Ports exposés

Ce module expose les ports suivants:

- 8081: Interface d'administration ioBroker
- 8082: ioBroker.web
- 8083-8085, 8087: Ports pour divers adaptateurs
- 9000 (UDP): Port multicast

## Options de configuration

| Option | Description |
|--------|-------------|
| `backup_directory` | Répertoire pour les sauvegardes de ioBroker |

## Sauvegarde et restauration

Le module inclut un utilitaire pour gérer les sauvegardes:

```bash
# Créer une sauvegarde
iobroker-helper backup

# Lister les sauvegardes disponibles
iobroker-helper list

# Restaurer à partir d'une sauvegarde
iobroker-helper restore /chemin/vers/sauvegarde.tar.gz
```

## Intégration avec Home Assistant

Pour intégrer les appareils ioBroker dans Home Assistant, nous vous recommandons d'utiliser:

1. L'adaptateur MQTT dans ioBroker avec le broker MQTT de Home Assistant
2. L'adaptateur ioBroker.iot pour exposer les appareils directement à Home Assistant

## Support et contribution

En cas de problème ou pour contribuer au développement de ce module complémentaire, veuillez visiter le dépôt GitHub du projet.

## Licence

Ce projet est sous licence MIT. 