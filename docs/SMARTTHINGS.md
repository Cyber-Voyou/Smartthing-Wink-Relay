# Installation SmartThings

## Canal communautaire

Canal bêta : [accepter l'invitation SmartThings](https://bestow-regional.api.smartthings.com/invite/6Vjd33D8yvlN).

L'utilisateur devra :

1. accepter l'invitation avec son compte Samsung;
2. inscrire son hub au canal;
3. installer **SmartThings Wink Relay MQTT**;
4. dans l'application mobile, lancer **Ajouter un appareil → Rechercher à proximité**;
5. effectuer un scan par Wink à créer;
6. renommer l'appareil et ouvrir ses paramètres.

## Paramètres de chaque appareil

- adresse et port du broker;
- préfixe identique à `mqtt_topic_prefix`;
- compte MQTT SmartThings dédié et son mot de passe;
- « One light » si `relay_lower_flags` inclut le bit `32`;
- accepter le risque de stockage des préférences;
- activer MQTT en dernier.

Chaque appareil possède sa propre socket et ses propres paramètres. La suppression d'un Wink n'arrête pas les autres. Le mot de passe est une préférence SmartThings masquée dans l'interface, mais ce n'est pas un coffre-fort matériel : utilisez un compte dédié à ACL minimale, révocable et rotatif.

## Construction depuis les sources

Installer le [CLI SmartThings officiel](https://github.com/SmartThingsCommunity/smartthings-cli), s'authentifier, puis :

```sh
smartthings edge:drivers:package driver
smartthings edge:channels:create
smartthings edge:channels:assign
smartthings edge:channels:enroll
smartthings edge:drivers:install
```

La publication dans un canal n'est pas une certification Works With SmartThings.
