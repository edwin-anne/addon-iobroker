# Module complémentaire ioBroker

## Configuration

### Option: `backup_directory`

Définit le répertoire où seront stockées les sauvegardes ioBroker. Par défaut, ce répertoire est `/share/iobroker_backups`.

## Installation

L'installation du module complémentaire est simple:

1. Ajoutez le référentiel de ce module complémentaire à votre installation Home Assistant:
   - Accédez à "Configuration" > "Modules complémentaires" > "Magasin de modules complémentaires"
   - Cliquez sur les trois points en haut à droite et sélectionnez "Référentiels"
   - Ajoutez l'URL du référentiel (par exemple: `https://github.com/votre-username/ha-iobroker`)
   - Cliquez sur "Ajouter"

2. Recherchez "ioBroker" dans le magasin de modules complémentaires
3. Cliquez sur "Installer"
4. Attendez que l'installation soit terminée (cela peut prendre plusieurs minutes)
5. Configurez les options si nécessaire
6. Démarrez le module complémentaire

## Première utilisation

Après le démarrage du module complémentaire, ioBroker sera automatiquement installé et configuré. L'interface d'administration sera accessible via:

- L'onglet "ioBroker" dans le tableau de bord de Home Assistant
- Directement à l'adresse: `http://votre-ip-ha:8081`

La première configuration d'ioBroker peut prendre quelques minutes. Soyez patient pendant ce processus.

## Adaptateurs recommandés

Pour une utilisation avec Home Assistant, nous recommandons d'installer les adaptateurs suivants:

1. **Admin** - Interface d'administration (installé par défaut)
2. **MQTT** - Pour l'intégration avec le broker MQTT de Home Assistant
3. **IoT** - Pour exposer les appareils ioBroker directement à Home Assistant
4. **History** - Pour l'historisation des données
5. **Vis** - Pour créer des tableaux de bord personnalisés

## Intégration avec Home Assistant

### Via MQTT

1. Installez l'adaptateur MQTT dans ioBroker
2. Configurez-le pour utiliser le broker MQTT de Home Assistant:
   - Adresse: `core-mosquitto`
   - Port: `1883`
   - Nom d'utilisateur et mot de passe: configurés dans votre broker MQTT Home Assistant

### Via l'adaptateur IoT

1. Installez l'adaptateur IoT dans ioBroker
2. Suivez les instructions pour configurer l'intégration avec Home Assistant
3. Vous pouvez alors exposer vos appareils ioBroker à Home Assistant

## Sauvegarde et restauration

### Création d'une sauvegarde manuelle

Pour créer une sauvegarde manuelle:

```bash
iobroker-helper backup
```

La sauvegarde sera stockée dans le répertoire configuré sous forme d'archive `.tar.gz`.

### Restauration d'une sauvegarde

Pour restaurer à partir d'une sauvegarde:

```bash
iobroker-helper restore /chemin/vers/sauvegarde.tar.gz
```

Attention: Cette opération arrêtera ioBroker, supprimera l'installation actuelle et la remplacera par celle de la sauvegarde.

## Dépannage

### Problèmes de permission

Si vous rencontrez des problèmes de permission, vous pouvez exécuter cette commande pour corriger les permissions:

```bash
chown -R iobroker:iobroker /opt/iobroker
```

### Journaux

Pour consulter les journaux du module complémentaire:

1. Accédez à "Configuration" > "Modules complémentaires" > "ioBroker"
2. Cliquez sur l'onglet "Journal"

Pour les journaux spécifiques à ioBroker, consultez l'interface d'administration d'ioBroker.

### Redémarrage

Si ioBroker ne répond plus, vous pouvez le redémarrer en redémarrant le module complémentaire depuis l'interface Home Assistant.

## Support

Si vous rencontrez des problèmes avec ce module complémentaire, veuillez:

1. Consulter la documentation
2. Vérifier les journaux pour identifier l'erreur
3. Ouvrir une issue sur le dépôt GitHub du projet 