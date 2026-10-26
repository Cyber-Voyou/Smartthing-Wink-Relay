# Smartthing - Wink Relay

Pilote communautaire SmartThings Edge pour contrôler un ou deux relais Wink Relay par MQTT et afficher température, humidité et état d'écran.

## Fonctionnalités

- un appareil SmartThings indépendant par Wink Relay;
- profil à deux relais ou profil « une lumière »;
- états MQTT reçus sans état optimiste;
- reconnexion non bloquante avec délai exponentiel;
- commandes limitées à `<prefix>/relays/0|1` et `ON/OFF`;
- aucune commande écran, redémarrage ou arrêt;
- aucune restauration automatique des relais au démarrage;
- fermeture de la socket lors d'une suppression, reconfiguration ou extinction du pilote;
- aucun identifiant dans le code, le ZIP ou les exemples.

## Architecture

```text
Wink Relay + wink_manager  ⇄  Mosquitto sur le LAN  ⇄  Hub SmartThings + pilote Edge  ⇄  application mobile
```

Commencez dans cet ordre :

1. [Installer et sécuriser Mosquitto](docs/MOSQUITTO.md).
2. [Installer Wink Relay Manager et préparer wink_manager.ini](docs/WINK_MANAGER.md).
3. [Installer/configurer le pilote SmartThings](docs/SMARTTHINGS.md).
4. Tester d'abord les états, puis une seule lumière sous surveillance.

Canal Edge bêta : [installer via l'invitation SmartThings](https://bestow-regional.api.smartthings.com/invite/6Vjd33D8yvlN). La version générique est publiée dans le cloud, mais n'a pas encore été installée sur un hub de test; conservez MQTT désactivé jusqu'à la fin de la configuration.

## Topics utilisés

| Sens | Topic |
|---|---|
| Wink → SmartThings | `<prefix>/relays/0/state` |
| Wink → SmartThings | `<prefix>/relays/1/state` |
| Wink → SmartThings | `<prefix>/sensors/temperature` |
| Wink → SmartThings | `<prefix>/sensors/humidity` |
| Wink → SmartThings | `<prefix>/screen/state` |
| SmartThings → Wink | `<prefix>/relays/0` |
| SmartThings → Wink | `<prefix>/relays/1` |

## Avertissements

Ce projet n'est affilié ni à Wink, ni à Samsung, ni à Eclipse. Le Wink Relay travaille sur le secteur : coupez l'alimentation avant toute intervention électrique et faites appel à un électricien qualifié. L'installation de `wink_manager` exige un appareil rooté et modifie `/system`. Utilisation à vos risques.

MQTT 1883 n'est pas chiffré. Ne l'exposez jamais sur Internet. Utilisez des comptes distincts avec ACL minimales et changez immédiatement tout secret divulgué.

## État du projet

La branche publique est dérivée d'une installation domestique validée avec quatre Wink, mais elle utilise un package et un canal séparés afin de ne pas modifier cette installation. La première version publique doit encore être validée sur un hub de test avant d'être annoncée comme stable.

Licence MIT. Voir [SECURITY.md](SECURITY.md) et [CONTRIBUTING.md](CONTRIBUTING.md).
