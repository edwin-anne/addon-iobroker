# ioBroker pour Home Assistant

## Introduction

ioBroker est une solution d'intégration pour l'Internet des objets, particulièrement adaptée à la domotique. 
Cette plateforme open-source offre une grande flexibilité et s'intègre avec de nombreux systèmes et dispositifs.

Avec cet add-on, vous pouvez exécuter ioBroker directement dans votre installation Home Assistant, ce qui vous permet 
de bénéficier des avantages des deux plateformes sans avoir besoin d'un autre appareil ou serveur.

## Installation

Pour installer cet add-on sur votre Home Assistant, suivez ces étapes:

1. Naviguez jusqu'à la section Add-on Store dans Home Assistant
2. Cliquez sur les trois points en haut à droite et sélectionnez "Repositories"
3. Ajoutez l'URL de ce dépôt
4. Cherchez "ioBroker" dans la liste des add-ons disponibles
5. Cliquez sur "Install"

## Configuration

L'add-on fonctionne sans configuration particulière. 

Options disponibles:
- `log_level`: Définit le niveau de détail des journaux (par défaut: "info")

## Volumes persistants

Cet add-on utilise des volumes persistants pour stocker les données d'ioBroker. Les données seront conservées même si vous désinstallez/réinstallez l'add-on.

## Ports

| Port | Description |
|------|-------------|
| 8081 | Interface web d'administration ioBroker |
| 8082 | API REST ioBroker |
| 8083 | Interface ioBroker.vis |
| 8084 | Interface ioBroker.vis-2 |
| 8085-8090 | Ports supplémentaires pour adaptateurs |
| 9000 | ioBroker.cloud |
| 9001 | Port supplémentaire |

## Utilisation

### Première configuration

Après le démarrage de l'add-on:

1. Accédez à l'interface web d'administration à l'adresse `http://votre-ip-homeassistant:8081`
2. Suivez l'assistant de configuration initial si c'est votre première utilisation
3. Installez les adaptateurs nécessaires via l'onglet "Adaptateurs"

### Installation d'adaptateurs

ioBroker utilise un système d'adaptateurs pour ajouter des fonctionnalités:

1. Dans l'interface web, allez dans l'onglet "Adaptateurs"
2. Recherchez et installez les adaptateurs dont vous avez besoin
3. Configurez chaque adaptateur selon vos besoins

### Intégration avec Home Assistant

Pour une intégration optimale entre ioBroker et Home Assistant:

1. Installez l'adaptateur "ioBroker.homeassistant" dans ioBroker
2. Configurez-le avec l'URL de votre API Home Assistant et un token d'accès
3. Sélectionnez les entités Home Assistant que vous souhaitez utiliser dans ioBroker

## Dépannage

### Problèmes d'accès à l'interface web

Si vous ne pouvez pas accéder à l'interface web d'ioBroker:
1. Vérifiez que l'add-on est bien démarré
2. Vérifiez les journaux pour identifier d'éventuelles erreurs
3. Assurez-vous que le port 8081 n'est pas bloqué par votre réseau

### Problèmes avec les adaptateurs

Si un adaptateur ne fonctionne pas correctement:
1. Vérifiez sa configuration dans l'interface d'ioBroker
2. Consultez les journaux spécifiques à cet adaptateur
3. Recherchez des informations sur le forum ioBroker ou la documentation de l'adaptateur

## FAQ

**Q: Puis-je utiliser ioBroker et Home Assistant ensemble?**
R: Oui, les deux systèmes peuvent fonctionner en parallèle et même s'intégrer l'un à l'autre.

**Q: Où sont stockées les données d'ioBroker?**
R: Dans le dossier `/data/iobroker` de votre installation Home Assistant.

**Q: Est-il possible d'accéder à ioBroker depuis l'extérieur de mon réseau?**
R: Oui, si vous avez configuré l'accès distant à votre Home Assistant, vous pourrez également accéder à ioBroker. 