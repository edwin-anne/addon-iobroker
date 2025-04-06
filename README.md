# ioBroker pour Home Assistant

Ce module complémentaire vous permet d'exécuter la plateforme domotique open-source ioBroker directement dans votre installation Home Assistant.

## À propos d'ioBroker

ioBroker est une solution d'intégration pour l'Internet des objets, qui se concentre sur la domotique, la surveillance à distance, l'automatisation et bien plus encore. Le système est modulaire et peut être étendu grâce à des "adaptateurs" qui représentent différents appareils, systèmes ou services.

## Caractéristiques

- Interface web puissante et personnalisable
- Nombreux adaptateurs disponibles pour connecter différents appareils et services
- Fonctionne en parallèle avec Home Assistant pour une flexibilité maximale
- Fonctionnalités avancées de visualisation et de tableau de bord

## Installation

1. Ajoutez le dépôt du module complémentaire à votre instance Home Assistant
2. Installez le module complémentaire "ioBroker"
3. Démarrez le module complémentaire
4. Accédez à l'interface web d'ioBroker à l'adresse : `http://votre-ip-home-assistant:8081`

## Configuration

Ce module complémentaire ne nécessite pas de configuration particulière pour fonctionner.

## Utilisation

Après le démarrage de l'add-on, ioBroker sera accessible sur le port 8081 de votre instance Home Assistant.

1. Accédez à l'interface d'administration d'ioBroker à l'adresse `http://votre-ip-home-assistant:8081`
2. Suivez les étapes initiales de configuration d'ioBroker
3. Installez les adaptateurs nécessaires pour votre utilisation

## Ports utilisés

- 8081: Interface web d'administration
- 8082: API REST
- 8083-8090, 9000-9001: Ports supplémentaires pour divers adaptateurs

## Support

Si vous rencontrez des problèmes avec ce module complémentaire, veuillez consulter la [documentation officielle d'ioBroker](https://www.iobroker.net/#de/documentation) ou les [forums de la communauté ioBroker](https://forum.iobroker.net/). 