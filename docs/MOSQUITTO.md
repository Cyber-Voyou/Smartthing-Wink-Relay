# Mosquitto sécurisé

Le pilote utilise MQTT 3.1.1 sur le réseau local. Il n'embarque aucun broker. Mosquitto 2.x est recommandé.

## Installation Debian/Ubuntu

```sh
sudo apt update
sudo apt install mosquitto mosquitto-clients
sudo install -m 0640 examples/mosquitto/mosquitto.conf.example /etc/mosquitto/conf.d/wink-relay.conf
sudo install -m 0640 examples/mosquitto/acl.example /etc/mosquitto/acl
sudo touch /etc/mosquitto/passwords
sudo chown mosquitto:mosquitto /etc/mosquitto/passwords /etc/mosquitto/acl
sudo chmod 0640 /etc/mosquitto/passwords /etc/mosquitto/acl
```

Créer deux comptes par Wink : un pour `wink_manager`, un pour SmartThings. La commande interactive évite le mot de passe dans l'historique :

```sh
sudo mosquitto_passwd /etc/mosquitto/passwords wink-kitchen
sudo mosquitto_passwd /etc/mosquitto/passwords smartthings-kitchen
sudo systemctl restart mosquitto
```

Adapter l'ACL à chaque préfixe. Ne jamais utiliser `mosquitto_passwd -c` sur un fichier existant : `-c` l'écrase.

## Docker Compose

Créer `config`, `data` et `log`, copier les deux exemples dans `config`, puis créer le fichier de mots de passe avec l'image Mosquitto :

```yaml
services:
  mosquitto:
    image: eclipse-mosquitto:2
    restart: unless-stopped
    ports: ["1883:1883"]
    volumes:
      - ./config:/mosquitto/config
      - ./data:/mosquitto/data
      - ./log:/mosquitto/log
```

```sh
docker run --rm -it -v "$PWD/config:/mosquitto/config" eclipse-mosquitto:2 mosquitto_passwd /mosquitto/config/passwords wink-kitchen
docker run --rm -it -v "$PWD/config:/mosquitto/config" eclipse-mosquitto:2 mosquitto_passwd /mosquitto/config/passwords smartthings-kitchen
docker compose up -d
```

## Vérification

Depuis un autre poste, tester uniquement les états :

```sh
mosquitto_sub -h BROKER_IP -p 1883 -u smartthings-kitchen -P 'PASSWORD' -t 'wink_relay_kitchen/relays/+/state' -v
```

Éviter `-P` sur une machine multi-utilisateur : elle peut exposer le secret dans la liste des processus. Préférer un fichier de configuration client protégé, puis le supprimer.

Pour Internet ou un réseau non fiable, placer Mosquitto derrière TLS/VPN. Le pilote actuel parle MQTT TCP local, sans TLS; ne jamais exposer le port 1883 sur Internet.
